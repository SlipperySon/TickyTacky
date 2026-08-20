import Foundation
import GRDB

/// Local cache row for a tag. Soft-delete via `deleted_at`.
struct TagRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "tags"

    var id: String
    var name: String
    var color: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncedAt: Date? = nil

    enum Columns: String, ColumnExpression {
        case id, name, color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }
}
