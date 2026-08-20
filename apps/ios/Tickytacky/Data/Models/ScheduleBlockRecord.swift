import Foundation
import GRDB

/// Recurring weekly time block within a schedule. One row per weekday (MVP).
/// Times are hour/minute components; overnight spans are rejected in validation.
struct ScheduleBlockRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "schedule_blocks"

    var id: String
    var scheduleId: String
    var title: String
    var notes: String?
    /// Calendar weekday: 1 = Sunday … 7 = Saturday (Foundation `Calendar` convention).
    var weekday: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var color: String
    var listId: String?
    var reminderMinutesBefore: Int?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncedAt: Date? = nil

    enum Columns: String, ColumnExpression {
        case id, title, notes, weekday, color
        case scheduleId = "schedule_id"
        case startHour = "start_hour"
        case startMinute = "start_minute"
        case endHour = "end_hour"
        case endMinute = "end_minute"
        case listId = "list_id"
        case reminderMinutesBefore = "reminder_minutes_before"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, weekday, color
        case scheduleId = "schedule_id"
        case startHour = "start_hour"
        case startMinute = "start_minute"
        case endHour = "end_hour"
        case endMinute = "end_minute"
        case listId = "list_id"
        case reminderMinutesBefore = "reminder_minutes_before"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }
}
