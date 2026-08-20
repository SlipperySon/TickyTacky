import Foundation

/// Builds stable, idempotent reminder plans for tasks and timetable occurrences.
/// Pure — no `UNUserNotificationCenter`; unit-test identifiers and fire dates here.
enum ReminderRequestBuilder {
    /// iOS pending local notification soft budget.
    static let pendingBudget = 64

    /// Default wall-clock hour for date-only task reminders.
    static let dateOnlyDefaultHour = 9
    static let dateOnlyDefaultMinute = 0

    // MARK: - Identifiers

    static func taskIdentifier(taskId: String, offsetMinutes: Int) -> String {
        "tt.task.\(taskId).\(offsetMinutes)"
    }

    /// Uses `originalStart` so skip/reschedule identity stays stable across edits.
    static func blockIdentifier(
        blockId: String,
        originalStart: Date,
        minutesBefore: Int,
        calendar: Calendar = .current
    ) -> String {
        let stamp = compactStamp(originalStart, calendar: calendar)
        return "tt.block.\(blockId).\(stamp).\(minutesBefore)"
    }

    // MARK: - Task plans

    /// Skips completed / soft-deleted / undated tasks and past fire dates.
    static func plans(
        for task: TaskRecord,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderPlan] {
        guard task.deletedAt == nil, !task.isCompleted, let dueDay = task.dueDate else { return [] }
        let offsets = task.reminderOffsetsMinutes
        guard !offsets.isEmpty else { return [] }
        guard let dueInstant = dueInstant(for: task, dueDay: dueDay, calendar: calendar) else { return [] }

        return offsets.compactMap { minutes in
            guard let fire = calendar.date(byAdding: .minute, value: -minutes, to: dueInstant),
                  fire > now
            else { return nil }
            let body: String
            if minutes == 0 {
                body = "Due now"
            } else if minutes < 60 {
                body = "Due in \(minutes) min"
            } else if minutes % 60 == 0 {
                let hours = minutes / 60
                body = hours == 1 ? "Due in 1 hour" : "Due in \(hours) hours"
            } else {
                body = "Due soon"
            }
            return ReminderPlan(
                identifier: taskIdentifier(taskId: task.id, offsetMinutes: minutes),
                fireDate: fire,
                title: task.title,
                body: body,
                userInfo: [
                    ReminderUserInfoKey.kind: ReminderDeepLinkKind.task.rawValue,
                    ReminderUserInfoKey.taskId: task.id
                ]
            )
        }
    }

    // MARK: - Block / occurrence plans

    static func plans(
        for occurrence: ScheduleOccurrence,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ReminderPlan] {
        guard let minutes = occurrence.reminderMinutesBefore, minutes >= 0 else { return [] }
        guard let fire = calendar.date(byAdding: .minute, value: -minutes, to: occurrence.start),
              fire > now
        else { return [] }

        let body: String
        if minutes == 0 {
            body = "Starting now"
        } else {
            body = "Starts in \(minutes) min"
        }

        return [
            ReminderPlan(
                identifier: blockIdentifier(
                    blockId: occurrence.blockID,
                    originalStart: occurrence.originalStart,
                    minutesBefore: minutes,
                    calendar: calendar
                ),
                fireDate: fire,
                title: occurrence.title,
                body: body,
                userInfo: [
                    ReminderUserInfoKey.kind: ReminderDeepLinkKind.occurrence.rawValue,
                    ReminderUserInfoKey.blockId: occurrence.blockID,
                    ReminderUserInfoKey.originalStart: ISO8601DateFormatter().string(from: occurrence.originalStart)
                ]
            )
        ]
    }

    // MARK: - Budget

    /// Keeps the soonest `limit` future plans (ascending fire date). Drops the rest.
    static func prioritize(
        _ plans: [ReminderPlan],
        now: Date = Date(),
        limit: Int = pendingBudget
    ) -> [ReminderPlan] {
        plans
            .filter { $0.fireDate > now }
            .sorted { lhs, rhs in
                if lhs.fireDate != rhs.fireDate { return lhs.fireDate < rhs.fireDate }
                return lhs.identifier < rhs.identifier
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    // MARK: - Helpers

    /// Due instant: wall-clock when `hasDueTime`, else 09:00 on the due day.
    static func dueInstant(
        for task: TaskRecord,
        dueDay: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let day = calendar.startOfDay(for: dueDay)
        if task.hasDueTime, let hour = task.dueHour, let minute = task.dueMinute {
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }
        return calendar.date(
            bySettingHour: dateOnlyDefaultHour,
            minute: dateOnlyDefaultMinute,
            second: 0,
            of: day
        )
    }

    private static func compactStamp(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return String(
            format: "%04d%02d%02d%02d%02d%02d",
            c.year ?? 0,
            c.month ?? 0,
            c.day ?? 0,
            c.hour ?? 0,
            c.minute ?? 0,
            c.second ?? 0
        )
    }
}
