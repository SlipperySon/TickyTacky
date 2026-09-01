import EventKit
import Foundation

/// One-way publish + optional two-way pull of timetable occurrences into a dedicated
/// **Tickytacky** EventKit calendar.
@MainActor
final class EventKitCalendarPublisher {
    static let shared = EventKitCalendarPublisher()

    static let enabledKey = CalendarBridgeDefaultsKey.appleEnabled
    static let twoWayKey = CalendarBridgeDefaultsKey.appleTwoWay
    static let calendarTitle = "Tickytacky"
    static let providerID = "apple"
    static let horizonWeeks = CalendarOccurrenceLoader.horizonWeeks

    private let store = EKEventStore()
    private let idStore = CalendarExternalIDStore.shared
    private var refreshTask: Task<Void, Never>?
    private var pullTask: Task<Void, Never>?
    private var didConfigure = false
    private var eventStoreObserver: NSObjectProtocol?
    private var ignoringExternalChangesUntil: Date?

    private init() {}

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if !newValue {
                isTwoWayEnabled = false
                Task { await clearPublishedEvents() }
            }
        }
    }

    var isTwoWayEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.twoWayKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.twoWayKey) }
    }

    enum AuthorizationStatus: Equatable {
        case notDetermined
        case denied
        case restricted
        case fullAccess
        case writeOnly

        var isUsable: Bool {
            switch self {
            case .fullAccess, .writeOnly: true
            case .notDetermined, .denied, .restricted: false
            }
        }

        var allowsTwoWay: Bool {
            self == .fullAccess
        }

        var settingsLabel: String {
            switch self {
            case .notDetermined: "Not asked"
            case .denied: "Off"
            case .restricted: "Restricted"
            case .fullAccess: "On"
            case .writeOnly: "Write only"
            }
        }
    }

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEventStoreChanged()
            }
        }
    }

    func authorizationStatus() -> AuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .fullAccess
        case .writeOnly: return .writeOnly
        case .authorized: return .fullAccess // pre–iOS 17
        @unknown default: return .denied
        }
    }

    @discardableResult
    func requestAccess(preferFullAccess: Bool = true) async -> Bool {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                if preferFullAccess || isTwoWayEnabled {
                    return try await store.requestFullAccessToEvents()
                }
                return try await store.requestWriteOnlyAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }

    /// Enable path: request access if needed, then publish.
    func enableAndPublish(database: AppDatabase = .shared) async {
        isEnabled = true
        let status = authorizationStatus()
        if status == .notDetermined {
            _ = await requestAccess(preferFullAccess: isTwoWayEnabled)
        }
        await publish(database: database)
    }

    /// Enable two-way: requires full calendar access.
    @discardableResult
    func enableTwoWayAndPull(database: AppDatabase = .shared) async -> Bool {
        let status = authorizationStatus()
        if status == .notDetermined || status == .writeOnly {
            _ = await requestAccess(preferFullAccess: true)
        }
        guard authorizationStatus().allowsTwoWay else {
            isTwoWayEnabled = false
            return false
        }
        isTwoWayEnabled = true
        await pull(database: database)
        return true
    }

    func schedulePublish(database: AppDatabase = .shared) {
        guard isEnabled else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.publish(database: database)
        }
    }

    func schedulePull(database: AppDatabase = .shared) {
        guard isEnabled, isTwoWayEnabled else { return }
        pullTask?.cancel()
        pullTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await self?.pull(database: database)
        }
    }

    func publish(database: AppDatabase = .shared) async {
        configure()
        guard isEnabled else { return }
        let status = authorizationStatus()
        guard status.isUsable else { return }

        do {
            let calendar = try ensureTickytackyCalendar()
            let appCal = AppCalendar.gregorian
            let occurrences = try CalendarOccurrenceLoader.load(
                database: database,
                calendar: appCal,
                horizonWeeks: Self.horizonWeeks
            )
            let range = CalendarOccurrenceLoader.dateRange(
                for: occurrences,
                calendar: appCal,
                horizonWeeks: Self.horizonWeeks
            )
            let existing = fetchExistingEvents(in: calendar, from: range.start, to: range.end)
            var byOccurrenceId: [String: EKEvent] = [:]
            for event in existing {
                guard let id = occurrenceId(from: event) else { continue }
                if let prior = byOccurrenceId[id] {
                    try? store.remove(prior, span: .thisEvent, commit: false)
                }
                byOccurrenceId[id] = event
            }

            var keepIds = Set<String>()
            let publishedAt = Date()
            beginEchoSuppression()
            for occ in occurrences {
                keepIds.insert(occ.id)
                let event: EKEvent
                if let existing = byOccurrenceId[occ.id] {
                    event = existing
                    apply(occ, to: event)
                    try store.save(event, span: .thisEvent, commit: false)
                } else {
                    event = EKEvent(eventStore: store)
                    event.calendar = calendar
                    apply(occ, to: event)
                    try store.save(event, span: .thisEvent, commit: false)
                }
                if let eventId = event.eventIdentifier {
                    idStore.recordPublish(
                        provider: Self.providerID,
                        occurrenceId: occ.id,
                        externalEventId: eventId,
                        externalCalendarId: calendar.calendarIdentifier,
                        at: publishedAt
                    )
                }
            }

            for (id, event) in byOccurrenceId where !keepIds.contains(id) {
                try store.remove(event, span: .thisEvent, commit: false)
                idStore.remove(provider: Self.providerID, occurrenceId: id)
            }

            try store.commit()
        } catch {
            // Fail quietly; Settings shows auth state.
        }
    }

    /// Pull external title/time edits into Tickytacky when two-way is on.
    func pull(database: AppDatabase = .shared) async {
        configure()
        guard isEnabled, isTwoWayEnabled else { return }
        guard authorizationStatus().allowsTwoWay else { return }
        if let until = ignoringExternalChangesUntil, Date() < until { return }

        do {
            let calendar = try ensureTickytackyCalendar()
            let appCal = AppCalendar.gregorian
            let occurrences = try CalendarOccurrenceLoader.load(
                database: database,
                calendar: appCal,
                horizonWeeks: Self.horizonWeeks
            )
            let byId = Dictionary(uniqueKeysWithValues: occurrences.map { ($0.id, $0) })
            let range = CalendarOccurrenceLoader.dateRange(
                for: occurrences,
                calendar: appCal,
                horizonWeeks: Self.horizonWeeks
            )
            let existing = fetchExistingEvents(in: calendar, from: range.start, to: range.end)

            var didMutate = false
            for event in existing {
                guard let occId = occurrenceId(from: event),
                      let local = byId[occId],
                      let parts = ScheduleOccurrence.parseID(occId)
                else { continue }

                let mapping = idStore.mapping(provider: Self.providerID, occurrenceId: occId)
                let action = CalendarConflictResolver.resolve(
                    local: .init(title: local.title, start: local.start, end: local.end),
                    external: .init(
                        title: event.title ?? "",
                        start: event.startDate,
                        end: event.endDate,
                        lastModified: event.lastModifiedDate
                    ),
                    lastPublishedAt: mapping?.lastPublishedAt
                )

                switch action {
                case .ignore:
                    continue
                case .applyTitle(let title):
                    try applyTitle(title, blockId: parts.blockID, database: database)
                    didMutate = true
                case .applyReschedule(let start, let end):
                    _ = try database.schedules.rescheduleOccurrence(
                        blockId: parts.blockID,
                        originalStart: parts.originalStart,
                        newStart: start,
                        newEnd: end
                    )
                    didMutate = true
                case .applyTitleAndReschedule(let title, let start, let end):
                    try applyTitle(title, blockId: parts.blockID, database: database)
                    _ = try database.schedules.rescheduleOccurrence(
                        blockId: parts.blockID,
                        originalStart: parts.originalStart,
                        newStart: start,
                        newEnd: end
                    )
                    didMutate = true
                }
            }

            // External deletes are ignored: next publish recreates tagged events.
            if didMutate {
                beginEchoSuppression()
                NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
            }
        } catch {
            // ignore
        }
    }

    /// Removes Tickytacky-tagged events in the dedicated calendar (used when disabling).
    func clearPublishedEvents() async {
        configure()
        guard authorizationStatus().isUsable else {
            idStore.removeAll(provider: Self.providerID)
            idStore.appleCalendarIdentifier = nil
            return
        }
        do {
            let calendar = try ensureTickytackyCalendar()
            let appCal = AppCalendar.gregorian
            let start = appCal.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
            let end = appCal.date(byAdding: .weekOfYear, value: Self.horizonWeeks + 2, to: Date()) ?? Date()
            let existing = fetchExistingEvents(in: calendar, from: start, to: end)
            beginEchoSuppression()
            for event in existing where occurrenceId(from: event) != nil {
                try store.remove(event, span: .thisEvent, commit: false)
            }
            try store.commit()
        } catch {
            // ignore
        }
        idStore.removeAll(provider: Self.providerID)
        idStore.appleCalendarIdentifier = nil
    }

    // MARK: - Private

    private func handleEventStoreChanged() {
        guard isEnabled, isTwoWayEnabled else { return }
        if let until = ignoringExternalChangesUntil, Date() < until { return }
        schedulePull()
    }

    private func beginEchoSuppression(seconds: TimeInterval = 2.5) {
        ignoringExternalChangesUntil = Date().addingTimeInterval(seconds)
    }

    private func applyTitle(_ title: String, blockId: String, database: AppDatabase) throws {
        guard let block = try database.schedules.fetchBlock(id: blockId) else { return }
        _ = try database.schedules.updateBlock(
            id: block.id,
            title: title,
            notes: block.notes,
            weekday: block.weekday,
            startHour: block.startHour,
            startMinute: block.startMinute,
            endHour: block.endHour,
            endMinute: block.endMinute,
            color: block.color,
            listId: block.listId,
            reminderMinutesBefore: block.reminderMinutesBefore
        )
    }

    private func ensureTickytackyCalendar() throws -> EKCalendar {
        if let cachedId = idStore.appleCalendarIdentifier,
           let cached = store.calendar(withIdentifier: cachedId),
           cached.allowsContentModifications {
            return cached
        }

        if let existing = store.calendars(for: .event).first(where: {
            $0.title == Self.calendarTitle && $0.allowsContentModifications
        }) {
            idStore.appleCalendarIdentifier = existing.calendarIdentifier
            return existing
        }

        guard let source = preferredSource() else {
            throw CalendarBridgeError.noWritableSource
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        idStore.appleCalendarIdentifier = calendar.calendarIdentifier
        return calendar
    }

    private func preferredSource() -> EKSource? {
        let sources = store.sources
        if let local = sources.first(where: { $0.sourceType == .local }) {
            return local
        }
        if let calDAV = sources.first(where: { $0.sourceType == .calDAV }) {
            return calDAV
        }
        return sources.first(where: { $0.sourceType == .exchange })
            ?? store.defaultCalendarForNewEvents?.source
    }

    private func fetchExistingEvents(in calendar: EKCalendar, from: Date, to: Date) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: [calendar])
        return store.events(matching: predicate)
    }

    private func apply(_ occurrence: ScheduleOccurrence, to event: EKEvent) {
        event.title = occurrence.title
        event.startDate = occurrence.start
        event.endDate = occurrence.end
        event.isAllDay = false
        event.notes = occurrence.notes
        event.url = occurrence.calendarBridgeURL
    }

    private func occurrenceId(from event: EKEvent) -> String? {
        guard let url = event.url else { return nil }
        return ScheduleOccurrence.occurrenceId(fromCalendarBridgeURL: url)
    }
}

enum CalendarBridgeError: LocalizedError {
    case noWritableSource

    var errorDescription: String? {
        switch self {
        case .noWritableSource:
            "No writable calendar account found to create the Tickytacky calendar."
        }
    }
}
