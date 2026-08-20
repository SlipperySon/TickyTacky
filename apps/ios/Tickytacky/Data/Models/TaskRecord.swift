import Foundation
import GRDB

/// Local cache row for a task.
///
/// **Due date storage:** `due_date` is a DATETIME at **start-of-day** in the device
/// calendar (no time component). When `has_due_time` is true, `due_hour` / `due_minute`
/// hold the wall-clock time separately. Never store a mid-day Date in `due_date`.
struct TaskRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "tasks"

    var id: String
    var listId: String
    var title: String
    var notes: String?
    var isCompleted: Bool
    var completedAt: Date?
    /// Start-of-day in device calendar, or nil if undated.
    var dueDate: Date?
    var hasDueTime: Bool
    var dueHour: Int?
    var dueMinute: Int?
    var priority: Int
    var sortOrder: Int
    /// JSON blob for `RecurrenceRule`, or nil if not recurring.
    var recurrenceJson: String?
    /// JSON array of minutes-before-due offsets (e.g. `[0,15,60]`). Nil/empty = no reminders.
    var reminderOffsetsJson: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    /// Last successful sync of this row; dirty when nil or `updatedAt > syncedAt`.
    var syncedAt: Date? = nil

    enum Columns: String, ColumnExpression {
        case id, title, notes, priority
        case listId = "list_id"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case hasDueTime = "has_due_time"
        case dueHour = "due_hour"
        case dueMinute = "due_minute"
        case sortOrder = "sort_order"
        case recurrenceJson = "recurrence_json"
        case reminderOffsetsJson = "reminder_offsets_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, priority
        case listId = "list_id"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case dueDate = "due_date"
        case hasDueTime = "has_due_time"
        case dueHour = "due_hour"
        case dueMinute = "due_minute"
        case sortOrder = "sort_order"
        case recurrenceJson = "recurrence_json"
        case reminderOffsetsJson = "reminder_offsets_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    var priorityValue: Priority {
        get { Priority(rawValue: priority) ?? .none }
        set { priority = newValue.rawValue }
    }

    var recurrenceRule: RecurrenceRule? {
        get { RecurrenceRule.from(jsonString: recurrenceJson) }
        set { recurrenceJson = newValue?.jsonString() }
    }

    /// Minutes before the due instant to fire a reminder. Empty = none.
    var reminderOffsetsMinutes: [Int] {
        get {
            guard let reminderOffsetsJson,
                  let data = reminderOffsetsJson.data(using: .utf8),
                  let values = try? JSONDecoder().decode([Int].self, from: data)
            else { return [] }
            return values.filter { $0 >= 0 }.sorted()
        }
        set {
            let cleaned = Array(Set(newValue.filter { $0 >= 0 })).sorted()
            if cleaned.isEmpty {
                reminderOffsetsJson = nil
            } else if let data = try? JSONEncoder().encode(cleaned),
                      let string = String(data: data, encoding: .utf8)
            {
                reminderOffsetsJson = string
            } else {
                reminderOffsetsJson = nil
            }
        }
    }
}
