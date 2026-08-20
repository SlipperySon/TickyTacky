import Foundation
import GRDB

/// Junction row for the many-to-many link between tasks and tags.
struct TaskTagRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    static let databaseTableName = "task_tags"

    var taskId: String
    var tagId: String
    var createdAt: Date

    enum Columns: String, ColumnExpression {
        case taskId = "task_id"
        case tagId = "tag_id"
        case createdAt = "created_at"
    }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case tagId = "tag_id"
        case createdAt = "created_at"
    }
}
