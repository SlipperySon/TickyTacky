import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Schedules local notifications for tasks and timetable blocks.
///
/// Building fire dates / identifiers is pure (`ReminderRequestBuilder`).
/// This type owns permission + `UNUserNotificationCenter` I/O.
///
/// **Simulator:** APIs work; reliable delivery needs a physical device — see `ReminderScheduler.md`.
@MainActor
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    /// How far ahead to expand timetable occurrences for reminders.
    static let occurrenceHorizonDays = 14

    private let center = UNUserNotificationCenter.current()
    private var refreshTask: Task<Void, Never>?
    private var didConfigure = false

    private override init() {
        super.init()
    }

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        center.delegate = self
    }

    // MARK: - Permission (G1)

    enum AuthorizationStatus: Equatable {
        case notDetermined
        case denied
        case authorized
        case provisional
        case ephemeral

        var isUsable: Bool {
            switch self {
            case .authorized, .provisional, .ephemeral: true
            case .notDetermined, .denied: false
            }
        }

        var settingsLabel: String {
            switch self {
            case .notDetermined: "Not asked"
            case .denied: "Off"
            case .authorized: "On"
            case .provisional: "Provisional"
            case .ephemeral: "Ephemeral"
            }
        }
    }

    func authorizationStatus() async -> AuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .denied
        }
    }

    /// Requests alert + sound + badge. Safe to call repeatedly.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Ask only when the user opts into a reminder (first-set timing).
    func ensureAuthorizedForReminder() async {
        let status = await authorizationStatus()
        switch status {
        case .notDetermined:
            _ = await requestAuthorization()
        case .denied, .authorized, .provisional, .ephemeral:
            break
        }
    }

    func openSystemNotificationSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    // MARK: - Reschedule pipeline (G4 / G5)

    /// Debounced full refresh — call after create/update/delete/complete.
    func scheduleRefresh(database: AppDatabase = .shared) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.refresh(database: database)
        }
    }

    /// Rebuilds pending local notifications from the local cache (soonest-N budget).
    func refresh(database: AppDatabase = .shared) async {
        configure()
        let status = await authorizationStatus()
        guard status.isUsable else {
            await center.removeAllPendingNotificationRequests()
            return
        }

        var calendar = Calendar.current
        calendar.timeZone = .current
        let now = Date()

        let plans: [ReminderPlan]
        do {
            plans = try buildPlans(database: database, now: now, calendar: calendar)
        } catch {
            return
        }

        let selected = ReminderRequestBuilder.prioritize(plans, now: now)
        let selectedIds = Set(selected.map(\.identifier))

        let pending = await center.pendingNotificationRequests()
        let obsoletePending = pending.map(\.identifier).filter { id in
            !selectedIds.contains(id) && !id.hasPrefix("tt.focus.")
        }
        if !obsoletePending.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: obsoletePending)
        }

        let delivered = await center.deliveredNotifications()
        let obsoleteDelivered = delivered
            .map(\.request.identifier)
            .filter { id in
                id.hasPrefix("tt.") && !id.hasPrefix("tt.focus.") && !selectedIds.contains(id)
            }
        if !obsoleteDelivered.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: obsoleteDelivered)
        }

        for plan in selected {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.userInfo = plan.userInfo

            let comps = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: plan.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    // MARK: - Focus / Pomodoro (M-F4)

    static func focusNotificationId(sessionId: String) -> String {
        "tt.focus.\(sessionId)"
    }

    func scheduleFocusEnd(
        sessionId: String,
        fireDate: Date,
        title: String,
        body: String
    ) async {
        configure()
        let status = await authorizationStatus()
        guard status.isUsable else { return }
        guard fireDate > Date() else { return }

        let identifier = Self.focusNotificationId(sessionId: sessionId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            ReminderUserInfoKey.kind: ReminderDeepLinkKind.focus.rawValue,
            ReminderUserInfoKey.sessionId: sessionId,
        ]

        var calendar = Calendar.current
        calendar.timeZone = .current
        let comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelFocusEnd(sessionId: String) {
        let identifier = Self.focusNotificationId(sessionId: sessionId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - UNUserNotificationCenterDelegate (G7)

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let link = ReminderDeepLink.parse(userInfo: info) {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .tickytackyOpenReminderDeepLink,
                    object: link
                )
            }
        }
        completionHandler()
    }

    // MARK: - Private

    private func buildPlans(
        database: AppDatabase,
        now: Date,
        calendar: Calendar
    ) throws -> [ReminderPlan] {
        var plans: [ReminderPlan] = []

        let tasks = try database.dbQueue.read { db in
            try TaskRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                  AND is_completed = 0
                  AND due_date IS NOT NULL
                  AND reminder_offsets_json IS NOT NULL
                  AND reminder_offsets_json != ''
                  AND reminder_offsets_json != '[]'
                """
            )
        }
        for task in tasks {
            plans.append(contentsOf: ReminderRequestBuilder.plans(for: task, now: now, calendar: calendar))
        }

        let from = calendar.startOfDay(for: now)
        guard let to = calendar.date(byAdding: .day, value: Self.occurrenceHorizonDays, to: from) else {
            return plans
        }
        let schedule = try database.schedules.ensureDefaultSchedule()
        let blocks = try database.schedules.fetchBlocks(scheduleId: schedule.id)
            .filter { $0.reminderMinutesBefore != nil }
        guard !blocks.isEmpty else { return plans }

        let exceptions = try database.schedules.fetchExceptions(
            blockIds: blocks.map(\.id),
            from: from,
            to: to
        )
        let occurrences = OccurrenceGenerator.occurrences(
            blocks: blocks.map(ScheduleBlockInput.init(from:)),
            exceptions: exceptions.map(ScheduleExceptionInput.init(from:)),
            from: from,
            to: to,
            calendar: calendar
        )
        for occurrence in occurrences {
            plans.append(contentsOf: ReminderRequestBuilder.plans(for: occurrence, now: now, calendar: calendar))
        }
        return plans
    }
}
