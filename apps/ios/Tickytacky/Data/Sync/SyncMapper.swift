import Foundation

/// Maps between local GRDB records and remote Supabase row shapes.
/// See `SyncMapping.md` for the full contract.
enum SyncMapper {
    // MARK: - Priority

    static func priorityToRemote(_ value: Int) -> String {
        switch Priority(rawValue: value) ?? .none {
        case .none: "none"
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        case .urgent: "urgent"
        }
    }

    static func priorityFromRemote(_ value: String) -> Int {
        switch value {
        case "low": Priority.low.rawValue
        case "medium": Priority.medium.rawValue
        case "high": Priority.high.rawValue
        case "urgent": Priority.urgent.rawValue
        default: Priority.none.rawValue
        }
    }

    // MARK: - Weekday (Calendar 1=Sun…7=Sat ↔ ISO 1=Mon…7=Sun)

    static func calendarWeekdayToISO(_ weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }

    static func isoWeekdayToCalendar(_ iso: Int) -> Int {
        iso == 7 ? 1 : iso + 1
    }

    static func calendarWeekdaysToISO(_ weekdays: [Int]?) -> [Int]? {
        weekdays.map { $0.map(calendarWeekdayToISO) }
    }

    static func isoWeekdaysToCalendar(_ weekdays: [Int]?) -> [Int]? {
        weekdays.map { $0.map(isoWeekdayToCalendar) }
    }

    // MARK: - Date / time strings

    static func formatDateOnly(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func parseDateOnly(_ string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) }
    }

    static func formatTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d:00", hour, minute)
    }

    static func parseTime(_ string: String) -> (hour: Int, minute: Int)? {
        let parts = string.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return (h, m)
    }

    // MARK: - Dirty

    static func isDirty(updatedAt: Date, syncedAt: Date?) -> Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }

    /// Empty / whitespace → nil so we never store `''` in Postgres.
    static func compactToken(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(16))
    }

    static func compactText(_ value: String?, max: Int) -> String? {
        guard let value else { return nil }
        guard !value.isEmpty else { return nil }
        return String(value.prefix(max))
    }

    // MARK: - Lists

    static func toRemote(list: TaskListRecord, userId: String) -> RemoteList {
        RemoteList(
            id: RecordID.normalize(list.id),
            user_id: userId,
            name: list.name,
            color: compactToken(list.color),
            is_inbox: list.isInbox,
            sort_order: list.sortOrder,
            created_at: list.createdAt,
            updated_at: list.updatedAt,
            deleted_at: list.deletedAt
        )
    }

    static func toLocal(list: RemoteList) -> TaskListRecord {
        TaskListRecord(
            id: RecordID.normalize(list.id),
            name: list.name,
            color: list.color,
            icon: nil, // cloud no longer stores icon (local-only if set later)
            sortOrder: list.sort_order,
            isInbox: list.is_inbox,
            createdAt: list.created_at,
            updatedAt: list.updated_at,
            deletedAt: list.deleted_at,
            syncedAt: list.updated_at
        )
    }

    // MARK: - Tags

    static func toRemote(tag: TagRecord, userId: String) -> RemoteTag {
        RemoteTag(
            id: RecordID.normalize(tag.id),
            user_id: userId,
            name: tag.name,
            color: compactToken(tag.color),
            created_at: tag.createdAt,
            updated_at: tag.updatedAt,
            deleted_at: tag.deletedAt
        )
    }

    static func toLocal(tag: RemoteTag) -> TagRecord {
        TagRecord(
            id: RecordID.normalize(tag.id),
            name: tag.name,
            color: tag.color,
            createdAt: tag.created_at,
            updatedAt: tag.updated_at,
            deletedAt: tag.deleted_at,
            syncedAt: tag.updated_at
        )
    }

    // MARK: - Tasks

    static func toRemote(task: TaskRecord, userId: String) -> RemoteTask {
        let dueDate = task.dueDate.map { formatDateOnly($0) }
        let dueTime: String? = {
            guard task.hasDueTime, let h = task.dueHour, let m = task.dueMinute else { return nil }
            return formatTime(hour: h, minute: m)
        }()

        var frequency: String?
        var interval: Int?
        var start: String?
        if let rule = task.recurrenceRule {
            frequency = rule.frequency.rawValue
            interval = rule.interval
            start = formatDateOnly(rule.startDate)
        }

        return RemoteTask(
            id: RecordID.normalize(task.id),
            user_id: userId,
            list_id: RecordID.normalize(task.listId),
            title: String(task.title.prefix(280)),
            notes: compactText(task.notes, max: 8000),
            is_completed: task.isCompleted,
            completed_at: task.completedAt,
            due_date: dueDate,
            due_time: dueTime,
            priority: priorityToRemote(task.priority),
            sort_order: task.sortOrder,
            recurrence_frequency: frequency,
            recurrence_interval: interval,
            recurrence_start: start,
            created_at: task.createdAt,
            updated_at: task.updatedAt,
            deleted_at: task.deletedAt
        )
    }

    /// - Parameter inboxId: Used when remote `list_id` is null.
    /// - Parameter preservingReminders: Local-only reminder offsets kept across pull.
    static func toLocal(
        task: RemoteTask,
        inboxId: String,
        preservingRemindersFrom existing: TaskRecord? = nil
    ) -> TaskRecord {
        var hasDueTime = false
        var dueHour: Int?
        var dueMinute: Int?
        if let dueTime = task.due_time, let parsed = parseTime(dueTime) {
            hasDueTime = true
            dueHour = parsed.hour
            dueMinute = parsed.minute
        }

        var recurrenceJson: String?
        if let freqRaw = task.recurrence_frequency,
           let freq = RecurrenceFrequency(rawValue: freqRaw),
           let startRaw = task.recurrence_start,
           let start = parseDateOnly(startRaw)
        {
            let rule = RecurrenceRule(
                frequency: freq,
                interval: max(1, task.recurrence_interval ?? 1),
                startDate: start,
                byWeekdays: nil // cloud omits by_weekdays in MVP compact schema
            )
            recurrenceJson = rule.jsonString()
        }

        let listId = task.list_id.map(RecordID.normalize) ?? RecordID.normalize(inboxId)
        return TaskRecord(
            id: RecordID.normalize(task.id),
            listId: listId,
            title: task.title,
            notes: task.notes,
            isCompleted: task.is_completed,
            completedAt: task.completed_at,
            dueDate: task.due_date.flatMap { parseDateOnly($0) },
            hasDueTime: hasDueTime,
            dueHour: dueHour,
            dueMinute: dueMinute,
            priority: priorityFromRemote(task.priority),
            sortOrder: task.sort_order,
            recurrenceJson: recurrenceJson,
            reminderOffsetsJson: existing?.reminderOffsetsJson,
            createdAt: task.created_at,
            updatedAt: task.updated_at,
            deletedAt: task.deleted_at,
            syncedAt: task.updated_at
        )
    }

    // MARK: - Subtasks

    static func toRemote(subtask: SubtaskRecord, userId: String) -> RemoteSubtask {
        RemoteSubtask(
            id: RecordID.normalize(subtask.id),
            user_id: userId,
            task_id: RecordID.normalize(subtask.taskId),
            title: String(subtask.title.prefix(280)),
            is_completed: subtask.isCompleted,
            sort_order: subtask.sortOrder,
            created_at: subtask.createdAt,
            updated_at: subtask.updatedAt,
            deleted_at: subtask.deletedAt
        )
    }

    static func toLocal(subtask: RemoteSubtask) -> SubtaskRecord {
        SubtaskRecord(
            id: RecordID.normalize(subtask.id),
            taskId: RecordID.normalize(subtask.task_id),
            title: subtask.title,
            isCompleted: subtask.is_completed,
            sortOrder: subtask.sort_order,
            createdAt: subtask.created_at,
            updatedAt: subtask.updated_at,
            deletedAt: subtask.deleted_at,
            syncedAt: subtask.updated_at
        )
    }

    // MARK: - Schedules

    static func toRemote(schedule: ScheduleRecord, userId: String) -> RemoteSchedule {
        RemoteSchedule(
            id: RecordID.normalize(schedule.id),
            user_id: userId,
            name: schedule.name,
            is_active: schedule.isActive,
            color: compactToken(schedule.color),
            created_at: schedule.createdAt,
            updated_at: schedule.updatedAt,
            deleted_at: schedule.deletedAt
        )
    }

    static func toLocal(schedule: RemoteSchedule, preservingTimezoneFrom existing: ScheduleRecord? = nil) -> ScheduleRecord {
        ScheduleRecord(
            id: RecordID.normalize(schedule.id),
            name: schedule.name,
            isActive: schedule.is_active,
            timezone: existing?.timezone,
            color: schedule.color,
            createdAt: schedule.created_at,
            updatedAt: schedule.updated_at,
            deletedAt: schedule.deleted_at,
            syncedAt: schedule.updated_at
        )
    }

    // MARK: - Schedule blocks

    static func toRemote(block: ScheduleBlockRecord, userId: String) -> RemoteScheduleBlock {
        RemoteScheduleBlock(
            id: RecordID.normalize(block.id),
            user_id: userId,
            schedule_id: RecordID.normalize(block.scheduleId),
            title: String(block.title.prefix(160)),
            notes: compactText(block.notes, max: 2000),
            iso_weekday: calendarWeekdayToISO(block.weekday),
            start_time: formatTime(hour: block.startHour, minute: block.startMinute),
            end_time: formatTime(hour: block.endHour, minute: block.endMinute),
            color: compactToken(block.color),
            list_id: block.listId.map(RecordID.normalize),
            reminder_minutes_before: block.reminderMinutesBefore,
            created_at: block.createdAt,
            updated_at: block.updatedAt,
            deleted_at: block.deletedAt
        )
    }

    static func toLocal(block: RemoteScheduleBlock) -> ScheduleBlockRecord {
        let start = parseTime(block.start_time) ?? (0, 0)
        let end = parseTime(block.end_time) ?? (0, 0)
        return ScheduleBlockRecord(
            id: RecordID.normalize(block.id),
            scheduleId: RecordID.normalize(block.schedule_id),
            title: block.title,
            notes: block.notes,
            weekday: isoWeekdayToCalendar(block.iso_weekday),
            startHour: start.hour,
            startMinute: start.minute,
            endHour: end.hour,
            endMinute: end.minute,
            color: block.color ?? PastelSwatch.sage.rawValue,
            listId: block.list_id.map(RecordID.normalize),
            reminderMinutesBefore: block.reminder_minutes_before,
            createdAt: block.created_at,
            updatedAt: block.updated_at,
            deletedAt: block.deleted_at,
            syncedAt: block.updated_at
        )
    }

    // MARK: - Exceptions

    static func toRemote(exception: ScheduleExceptionRecord, userId: String) -> RemoteScheduleException {
        RemoteScheduleException(
            id: RecordID.normalize(exception.id),
            user_id: userId,
            block_id: RecordID.normalize(exception.blockId),
            original_start: exception.originalStart,
            type: exception.type,
            new_start: exception.newStart,
            new_end: exception.newEnd,
            notes: compactText(exception.notes, max: 500),
            created_at: exception.createdAt,
            updated_at: exception.updatedAt,
            deleted_at: exception.deletedAt
        )
    }

    static func toLocal(exception: RemoteScheduleException) -> ScheduleExceptionRecord {
        ScheduleExceptionRecord(
            id: RecordID.normalize(exception.id),
            blockId: RecordID.normalize(exception.block_id),
            originalStart: exception.original_start,
            type: exception.type,
            newStart: exception.new_start,
            newEnd: exception.new_end,
            notes: exception.notes,
            createdAt: exception.created_at,
            updatedAt: exception.updated_at,
            deletedAt: exception.deleted_at,
            syncedAt: exception.updated_at
        )
    }
}
