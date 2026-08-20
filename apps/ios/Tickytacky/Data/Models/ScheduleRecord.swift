import Foundation
import GRDB

/// Named timetable container (e.g. “Semester 1”). Soft-delete via `deleted_at`.
struct ScheduleRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "schedules"

    var id: String
    var name: String
    var isActive: Bool
    var timezone: String?
    var color: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncedAt: Date? = nil

    enum Columns: String, ColumnExpression {
        case id, name, color, timezone
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, timezone
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }
}
