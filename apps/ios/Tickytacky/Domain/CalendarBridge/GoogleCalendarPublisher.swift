import Foundation

/// One-way publish + optional two-way pull into a dedicated Google Calendar titled **Tickytacky**.
@MainActor
final class GoogleCalendarPublisher {
    static let shared = GoogleCalendarPublisher()

    static let enabledKey = CalendarBridgeDefaultsKey.googleEnabled
    static let twoWayKey = CalendarBridgeDefaultsKey.googleTwoWay
    static let calendarTitle = "Tickytacky"
    static let providerID = "google"
    static let horizonWeeks = CalendarOccurrenceLoader.horizonWeeks
    static let occurrencePropertyKey = "tickytackyOccurrenceId"

    private let oauth = GoogleCalendarOAuth.shared
    private let api = GoogleCalendarAPI()
    private let idStore = CalendarExternalIDStore.shared
    private var didConfigure = false
    private var publishTask: Task<Void, Never>?
    private var pullTask: Task<Void, Never>?
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

    var isConfigured: Bool { oauth.isConfigured }
    var isSignedIn: Bool { oauth.isSignedIn }

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true
    }

    func signIn() async throws {
        guard isConfigured else { throw CalendarBridgeProviderError.missingClientID }
        try await oauth.signIn()
    }

    func signOut() {
        oauth.signOut()
    }

    func enableAndPublish(database: AppDatabase = .shared) async throws {
        guard isConfigured else { throw CalendarBridgeProviderError.missingClientID }
        if !isSignedIn {
            try await signIn()
        }
        isEnabled = true
        await publish(database: database)
    }

    @discardableResult
    func enableTwoWayAndPull(database: AppDatabase = .shared) async throws -> Bool {
        guard isEnabled else { return false }
        if !isSignedIn {
            try await signIn()
        }
        isTwoWayEnabled = true
        await pull(database: database)
        return true
    }

    func schedulePublish(database: AppDatabase = .shared) {
        guard isEnabled else { return }
        publishTask?.cancel()
        publishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.publish(database: database)
        }
    }

    func schedulePull(database: AppDatabase = .shared) {
        guard isEnabled, isTwoWayEnabled else { return }
        pullTask?.cancel()
        pullTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await self?.pull(database: database)
        }
    }

    func publish(database: AppDatabase = .shared) async {
        configure()
        guard isEnabled, isConfigured, isSignedIn else { return }

        do {
            let calendarId = try await ensureTickytackyCalendarId()
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

            let remoteByOccurrence = try await loadRemoteEventsByOccurrenceId(
                calendarId: calendarId,
                timeMin: range.start,
                timeMax: range.end
            )

            beginEchoSuppression()
            let publishedAt = Date()
            var keepIds = Set<String>()

            for occ in occurrences {
                keepIds.insert(occ.id)
                let write = makeEventWrite(for: occ)
                if let existing = remoteByOccurrence[occ.id], let eventId = existing.id {
                    let patched = try await api.patchEvent(
                        calendarId: calendarId,
                        eventId: eventId,
                        event: write
                    )
                    idStore.recordPublish(
                        provider: Self.providerID,
                        occurrenceId: occ.id,
                        externalEventId: patched.id ?? eventId,
                        externalCalendarId: calendarId,
                        at: publishedAt
                    )
                } else {
                    let created = try await api.insertEvent(calendarId: calendarId, event: write)
                    if let eventId = created.id {
                        idStore.recordPublish(
                            provider: Self.providerID,
                            occurrenceId: occ.id,
                            externalEventId: eventId,
                            externalCalendarId: calendarId,
                            at: publishedAt
                        )
                    }
                }
            }

            for (occId, event) in remoteByOccurrence where !keepIds.contains(occId) {
                if let eventId = event.id {
                    try await api.deleteEvent(calendarId: calendarId, eventId: eventId)
                }
                idStore.remove(provider: Self.providerID, occurrenceId: occId)
            }

            // Seed a fresh sync token after full publish window when two-way is on.
            if isTwoWayEnabled {
                _ = try? await refreshSyncToken(calendarId: calendarId, timeMin: range.start, timeMax: range.end)
            }
        } catch {
            // Fail quietly; Settings surfaces sign-in / config state.
        }
    }

    func pull(database: AppDatabase = .shared) async {
        configure()
        guard isEnabled, isTwoWayEnabled, isConfigured, isSignedIn else { return }
        if let until = ignoringExternalChangesUntil, Date() < until { return }

        do {
            let calendarId = try await ensureTickytackyCalendarId()
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

            let events: [GCalEvent]
            if let syncToken = idStore.googleSyncToken {
                do {
                    events = try await listAllEvents(
                        calendarId: calendarId,
                        timeMin: range.start,
                        timeMax: range.end,
                        syncToken: syncToken
                    )
                } catch GoogleCalendarAPIError.syncTokenExpired {
                    idStore.googleSyncToken = nil
                    events = try await listAllEvents(
                        calendarId: calendarId,
                        timeMin: range.start,
                        timeMax: range.end,
                        syncToken: nil
                    )
                }
            } else {
                events = try await listAllEvents(
                    calendarId: calendarId,
                    timeMin: range.start,
                    timeMax: range.end,
                    syncToken: nil
                )
            }

            var didMutate = false
            for event in events {
                // Cancelled / deleted externally → do not delete local blocks; republish later.
                if event.status == "cancelled" { continue }
                guard let occId = event.occurrenceId ?? occurrenceId(fromDescription: event.description),
                      let local = byId[occId],
                      let parts = ScheduleOccurrence.parseID(occId),
                      let start = event.start?.date,
                      let end = event.end?.date
                else { continue }

                let mapping = idStore.mapping(provider: Self.providerID, occurrenceId: occId)
                let action = CalendarConflictResolver.resolve(
                    local: .init(title: local.title, start: local.start, end: local.end),
                    external: .init(
                        title: event.summary ?? "",
                        start: start,
                        end: end,
                        lastModified: event.updatedDate
                    ),
                    lastPublishedAt: mapping?.lastPublishedAt
                )

                switch action {
                case .ignore:
                    continue
                case .applyTitle(let title):
                    try applyTitle(title, blockId: parts.blockID, database: database)
                    didMutate = true
                case .applyReschedule(let newStart, let newEnd):
                    _ = try database.schedules.rescheduleOccurrence(
                        blockId: parts.blockID,
                        originalStart: parts.originalStart,
                        newStart: newStart,
                        newEnd: newEnd
                    )
                    didMutate = true
                case .applyTitleAndReschedule(let title, let newStart, let newEnd):
                    try applyTitle(title, blockId: parts.blockID, database: database)
                    _ = try database.schedules.rescheduleOccurrence(
                        blockId: parts.blockID,
                        originalStart: parts.originalStart,
                        newStart: newStart,
                        newEnd: newEnd
                    )
                    didMutate = true
                }
            }

            if didMutate {
                beginEchoSuppression()
                NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
            }
        } catch {
            // ignore
        }
    }

    func clearPublishedEvents() async {
        configure()
        defer {
            idStore.removeAll(provider: Self.providerID)
            idStore.googleCalendarId = nil
            idStore.googleSyncToken = nil
        }
        guard isConfigured, isSignedIn else { return }
        do {
            let calendarId = try await ensureTickytackyCalendarId()
            let appCal = AppCalendar.gregorian
            let start = appCal.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
            let end = appCal.date(byAdding: .weekOfYear, value: Self.horizonWeeks + 2, to: Date()) ?? Date()
            let remote = try await loadRemoteEventsByOccurrenceId(
                calendarId: calendarId,
                timeMin: start,
                timeMax: end
            )
            beginEchoSuppression()
            for (_, event) in remote {
                if let eventId = event.id {
                    try await api.deleteEvent(calendarId: calendarId, eventId: eventId)
                }
            }
        } catch {
            // ignore
        }
    }

    // MARK: - Private

    private func beginEchoSuppression(seconds: TimeInterval = 2.5) {
        ignoringExternalChangesUntil = Date().addingTimeInterval(seconds)
    }

    private func ensureTickytackyCalendarId() async throws -> String {
        if let cached = idStore.googleCalendarId {
            return cached
        }
        let calendars = try await api.listCalendars()
        if let existing = calendars.first(where: { $0.summary == Self.calendarTitle }),
           let id = existing.id {
            idStore.googleCalendarId = id
            return id
        }
        let created = try await api.insertCalendar(summary: Self.calendarTitle)
        guard let id = created.id else {
            throw CalendarBridgeProviderError.notConfigured
        }
        idStore.googleCalendarId = id
        return id
    }

    private func loadRemoteEventsByOccurrenceId(
        calendarId: String,
        timeMin: Date,
        timeMax: Date
    ) async throws -> [String: GCalEvent] {
        let events = try await listAllEvents(
            calendarId: calendarId,
            timeMin: timeMin,
            timeMax: timeMax,
            syncToken: nil
        )
        var byId: [String: GCalEvent] = [:]
        for event in events {
            guard event.status != "cancelled",
                  let occId = event.occurrenceId ?? occurrenceId(fromDescription: event.description)
            else { continue }
            if let prior = byId[occId], let priorId = prior.id {
                // Duplicate tag — drop the older mapping's remote later via delete of prior.
                try? await api.deleteEvent(calendarId: calendarId, eventId: priorId)
            }
            byId[occId] = event
        }
        return byId
    }

    private func listAllEvents(
        calendarId: String,
        timeMin: Date?,
        timeMax: Date?,
        syncToken: String?
    ) async throws -> [GCalEvent] {
        var all: [GCalEvent] = []
        var pageToken: String?
        var latestSync: String?
        repeat {
            let page = try await api.listEvents(
                calendarId: calendarId,
                timeMin: syncToken == nil ? timeMin : nil,
                timeMax: syncToken == nil ? timeMax : nil,
                syncToken: syncToken,
                pageToken: pageToken
            )
            all.append(contentsOf: page.events)
            pageToken = page.nextPageToken
            if let token = page.nextSyncToken {
                latestSync = token
            }
        } while pageToken != nil

        if let latestSync {
            idStore.googleSyncToken = latestSync
        }
        return all
    }

    private func refreshSyncToken(calendarId: String, timeMin: Date, timeMax: Date) async throws -> String? {
        idStore.googleSyncToken = nil
        _ = try await listAllEvents(
            calendarId: calendarId,
            timeMin: timeMin,
            timeMax: timeMax,
            syncToken: nil
        )
        return idStore.googleSyncToken
    }

    private func makeEventWrite(for occurrence: ScheduleOccurrence) -> GCalEventWrite {
        var description = occurrence.notes ?? ""
        if let url = occurrence.calendarBridgeURL {
            if !description.isEmpty { description += "\n\n" }
            description += url.absoluteString
        }
        return GCalEventWrite(
            summary: occurrence.title,
            description: description.isEmpty ? nil : description,
            start: GCalDateTime(date: occurrence.start),
            end: GCalDateTime(date: occurrence.end),
            extendedProperties: GCalExtendedProperties(
                privateProps: [Self.occurrencePropertyKey: occurrence.id]
            )
        )
    }

    private func occurrenceId(fromDescription description: String?) -> String? {
        guard let description else { return nil }
        for line in description.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed) else { continue }
            if let id = ScheduleOccurrence.occurrenceId(fromCalendarBridgeURL: url) {
                return id
            }
        }
        return nil
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
}
