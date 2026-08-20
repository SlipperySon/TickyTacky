import Foundation
import GRDB

/// Local cache row for a subtask under a parent task.
struct SubtaskRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "subtasks"

    var id: String
    var taskId: String
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncedAt: Date? = nil

    enum Columns: String, ColumnExpression {
        case id, title
        case taskId = "task_id"
        case isCompleted = "is_completed"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, title
        case taskId = "task_id"
        case isCompleted = "is_completed"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case syncedAt = "synced_at"
    }
}
