import Foundation
import GRDB

/// One-off skip or move for a generated occurrence of a schedule block.
struct ScheduleExceptionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "schedule_exceptions"

    var id: String
    var blockId: String
    /// Occurrence identity: the would-be start datetime of the series occurrence.
    var originalStart: Date
    var type: String
    var newStart: Date?
    var newEnd: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncedAt: Date? = nil

    var exceptionType: ScheduleExceptionType {
        ScheduleExceptionType(rawValue: type) ?? .skip
    }

    enum Columns: String, ColumnExpression {
        case id, type, notes
        case blockId = "block_id"
        case originalStart = "original_start"
        case newStart = "new_start"
        case newEnd = "new_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, type, notes
        case blockId = "block_id"
        case originalStart = "original_start"
        case newStart = "new_start"
        case newEnd = "new_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }
}
