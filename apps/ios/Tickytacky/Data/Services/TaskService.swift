import Foundation
import GRDB
import os

enum ServiceError: LocalizedError {
    case validation(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .validation(let message): message
        case .notFound: "Not found."
        }
    }
}

/// Task + subtask CRUD against the local GRDB cache. Soft-delete only. No sync.
///
/// Sort rules for dated/incomplete surfaces: see `TaskOrdering`
/// (priority → due time → sortOrder).
final class TaskService: @unchecked Sendable {
    private let database: AppDatabase
    /// Guards double-tap advancing a recurring series twice.
    private let recentRecurrenceCompletes = OSAllocatedUnfairLock(initialState: [String: Date]())

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Fetch

    func fetch(id: String) throws -> TaskRecord? {
        try database.dbQueue.read { db in
            try TaskRecord
                .filter(TaskRecord.Columns.id == id && TaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    func fetchByList(listId: String, includeCompleted: Bool = true) throws -> [TaskRecord] {
        try database.dbQueue.read { db in
            var sql = """
            SELECT * FROM tasks
            WHERE list_id = ? AND deleted_at IS NULL
            """
            if !includeCompleted {
                sql += " AND is_completed = 0"
            }
            // List browse: completed last when shown, then canonical priority → due → sortOrder.
            sql += " " + TaskOrdering.sqlOrderByClause(
                includeCompletedBucket: includeCompleted,
                tableAlias: ""
            )
            return try TaskRecord.fetchAll(db, sql: sql, arguments: [listId])
        }
    }

    /// Incomplete tasks overdue (due before today) and due today.
    /// Sorted via `TaskOrdering` (priority → due time → sortOrder).
    func fetchToday() throws -> (overdue: [TaskRecord], dueToday: [TaskRecord]) {
        let today = DueDate.today()
        let tomorrow = DueDate.dayOffset(1)
        return try database.dbQueue.read { db in
            let overdue = try TaskRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                  AND is_completed = 0
                  AND due_date IS NOT NULL
                  AND due_date < ?
                \(TaskOrdering.sqlOrderByClause(includeCompletedBucket: false, tableAlias: ""))
                """,
                arguments: [today]
            )

            // Inclusive today via [today, tomorrow) to avoid Date float equality issues.
            let dueToday = try TaskRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                  AND is_completed = 0
                  AND due_date IS NOT NULL
                  AND due_date >= ?
                  AND due_date < ?
                \(TaskOrdering.sqlOrderByClause(includeCompletedBucket: false, tableAlias: ""))
                """,
                arguments: [today, tomorrow]
            )

            return (overdue, dueToday)
        }
    }

    /// Incomplete tasks due on a single calendar day (start-of-day inclusive).
    func fetchDue(on day: Date, calendar: Calendar = .current) throws -> [TaskRecord] {
        let start = DueDate.startOfDay(day, calendar: calendar)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try database.dbQueue.read { db in
            try TaskRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                  AND is_completed = 0
                  AND due_date IS NOT NULL
                  AND due_date >= ?
                  AND due_date < ?
                \(TaskOrdering.sqlOrderByClauseForUpcoming(tableAlias: ""))
                """,
                arguments: [start, end]
            )
        }
    }

    /// Incomplete tasks with due dates from tomorrow through `days` ahead, grouped by day.
    /// Within each day, sorted via `TaskOrdering` (priority → due time → sortOrder).
    func fetchUpcoming(days: Int = 7) throws -> [(day: Date, tasks: [TaskRecord])] {
        let tomorrow = DueDate.dayOffset(1)
        let endExclusive = DueDate.dayOffset(days + 1)
        let tasks = try database.dbQueue.read { db in
            try TaskRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                  AND is_completed = 0
                  AND due_date IS NOT NULL
                  AND due_date >= ?
                  AND due_date < ?
                \(TaskOrdering.sqlOrderByClauseForUpcoming(tableAlias: ""))
                """,
                arguments: [tomorrow, endExclusive]
            )
        }

        var grouped: [(day: Date, tasks: [TaskRecord])] = []
        var calendar = Calendar.current
        calendar.timeZone = .current
        for task in tasks {
            guard let due = task.dueDate else { continue }
            let day = DueDate.startOfDay(due, calendar: calendar)
            if let last = grouped.last, DueDate.isSameDay(last.day, day, calendar: calendar) {
                grouped[grouped.count - 1].tasks.append(task)
            } else {
                grouped.append((day, [task]))
            }
        }
        return grouped
    }

    // MARK: - Create / update / delete

    @discardableResult
    func create(
        title: String,
        listId: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        hasDueTime: Bool = false,
        dueHour: Int? = nil,
        dueMinute: Int? = nil,
        priority: Priority = .none
    ) throws -> TaskRecord {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Title cannot be empty.")
        }
        let now = Date()
        let normalizedDue = dueDate.map { DueDate.startOfDay($0) }
        let task = TaskRecord(
            id: RecordID.make(),
            listId: listId,
            title: trimmed,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            isCompleted: false,
            completedAt: nil,
            dueDate: normalizedDue,
            hasDueTime: normalizedDue != nil && hasDueTime,
            dueHour: (normalizedDue != nil && hasDueTime) ? dueHour : nil,
            dueMinute: (normalizedDue != nil && hasDueTime) ? dueMinute : nil,
            priority: priority.rawValue,
            sortOrder: 0,
            recurrenceJson: nil,
            reminderOffsetsJson: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try task.insert(db)
        }
        notifyRemindersChanged()
        return task
    }

    @discardableResult
    func update(_ task: TaskRecord) throws -> TaskRecord {
        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Title cannot be empty.")
        }
        var copy = task
        copy.title = trimmed
        copy.notes = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let due = task.dueDate {
            copy.dueDate = DueDate.startOfDay(due)
            if !task.hasDueTime {
                copy.hasDueTime = false
                copy.dueHour = nil
                copy.dueMinute = nil
            }
        } else {
            copy.dueDate = nil
            copy.hasDueTime = false
            copy.dueHour = nil
            copy.dueMinute = nil
        }
        copy.updatedAt = Date()
        try database.dbQueue.write { db in
            try copy.update(db)
        }
        notifyRemindersChanged()
        return copy
    }

    func softDelete(id: String) throws {
        try database.dbQueue.write { db in
            guard var task = try TaskRecord
                .filter(TaskRecord.Columns.id == id && TaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let now = Date()
            task.deletedAt = now
            task.updatedAt = now
            try task.update(db)
            try db.execute(
                sql: """
                UPDATE subtasks SET deleted_at = ?, updated_at = ?
                WHERE task_id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, id]
            )
        }
        notifyRemindersChanged()
    }

    /// Marks complete/incomplete. Recurring tasks (MVP policy): on complete, advance
    /// `due_date` via `RecurrenceEngine` and keep the row incomplete (series-only).
    @discardableResult
    func setCompleted(id: String, completed: Bool) throws -> TaskRecord {
        if completed {
            let now = Date()
            let shouldSkip = recentRecurrenceCompletes.withLock { map -> Bool in
                if let last = map[id], now.timeIntervalSince(last) < 0.8 {
                    return true
                }
                map[id] = now
                return false
            }
            if shouldSkip, let existing = try fetch(id: id), existing.recurrenceRule != nil {
                return existing
            }
        }

        let task = try database.dbQueue.write { db in
            guard var task = try TaskRecord
                .filter(TaskRecord.Columns.id == id && TaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let now = Date()
            if completed, let rule = task.recurrenceRule {
                var calendar = Calendar.current
                calendar.timeZone = .current
                let anchor = task.dueDate.map { DueDate.startOfDay($0, calendar: calendar) }
                    ?? DueDate.today(calendar: calendar)
                let next = RecurrenceEngine.nextDate(after: anchor, rule: rule, calendar: calendar)
                task.dueDate = DueDate.startOfDay(next, calendar: calendar)
                task.isCompleted = false
                task.completedAt = nil
            } else {
                task.isCompleted = completed
                task.completedAt = completed ? now : nil
            }
            task.updatedAt = now
            try task.update(db)
            return task
        }
        notifyRemindersChanged()
        return task
    }

    // MARK: - Subtasks

    func fetchSubtasks(taskId: String) throws -> [SubtaskRecord] {
        try database.dbQueue.read { db in
            try SubtaskRecord
                .filter(SubtaskRecord.Columns.taskId == taskId && SubtaskRecord.Columns.deletedAt == nil)
                .order(SubtaskRecord.Columns.sortOrder.asc, SubtaskRecord.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    @discardableResult
    func addSubtask(taskId: String, title: String) throws -> SubtaskRecord {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Subtask title cannot be empty.")
        }
        let now = Date()
        let maxOrder = try database.dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sort_order), -1) FROM subtasks WHERE task_id = ? AND deleted_at IS NULL",
                arguments: [taskId]
            ) ?? -1
        }
        let sub = SubtaskRecord(
            id: RecordID.make(),
            taskId: taskId,
            title: trimmed,
            isCompleted: false,
            sortOrder: maxOrder + 1,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try sub.insert(db)
        }
        return sub
    }

    @discardableResult
    func updateSubtask(_ subtask: SubtaskRecord) throws -> SubtaskRecord {
        var copy = subtask
        copy.title = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else {
            throw ServiceError.validation("Subtask title cannot be empty.")
        }
        copy.updatedAt = Date()
        try database.dbQueue.write { db in
            try copy.update(db)
        }
        return copy
    }

    @discardableResult
    func setSubtaskCompleted(id: String, completed: Bool) throws -> SubtaskRecord {
        try database.dbQueue.write { db in
            guard var sub = try SubtaskRecord
                .filter(SubtaskRecord.Columns.id == id && SubtaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            sub.isCompleted = completed
            sub.updatedAt = Date()
            try sub.update(db)
            return sub
        }
    }

    func softDeleteSubtask(id: String) throws {
        try database.dbQueue.write { db in
            guard var sub = try SubtaskRecord
                .filter(SubtaskRecord.Columns.id == id && SubtaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let now = Date()
            sub.deletedAt = now
            sub.updatedAt = now
            try sub.update(db)
        }
    }

    private func notifyRemindersChanged() {
        let database = self.database
        Task { @MainActor in
            ReminderScheduler.shared.scheduleRefresh(database: database)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
