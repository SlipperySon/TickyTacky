import Foundation
import GRDB

/// Local cache row for a task list. Mirrors planned Supabase `lists` shape.
struct TaskListRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "lists"

    var id: String
    var name: String
    var color: String?
    var icon: String?
    var sortOrder: Int
    var isInbox: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    /// Last successful sync of this row; dirty when nil or `updatedAt > syncedAt`.
    var syncedAt: Date? = nil

    enum Columns: String, ColumnExpression {
        case id, name, color, icon
        case sortOrder = "sort_order"
        case isInbox = "is_inbox"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon
        case sortOrder = "sort_order"
        case isInbox = "is_inbox"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }
}
