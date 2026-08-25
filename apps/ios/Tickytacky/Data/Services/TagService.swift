import Foundation
import GRDB

/// Tag CRUD + task attach/detach against the local GRDB cache. Soft-delete only.
final class TagService: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    struct TagSummary: Equatable, Identifiable, Sendable {
        var tag: TagRecord
        var openTaskCount: Int
        var id: String { tag.id }
    }

    // MARK: - Fetch

    func fetchAll() throws -> [TagRecord] {
        try database.dbQueue.read { db in
            try TagRecord
                .filter(TagRecord.Columns.deletedAt == nil)
                .order(TagRecord.Columns.name.asc)
                .fetchAll(db)
        }
    }

    func fetchSummaries() throws -> [TagSummary] {
        try database.dbQueue.read { db in
            let tags = try TagRecord
                .filter(TagRecord.Columns.deletedAt == nil)
                .order(TagRecord.Columns.name.asc)
                .fetchAll(db)
            return try tags.map { tag in
                let count = try Int.fetchOne(
                    db,
                    sql: """
                    SELECT COUNT(*) FROM task_tags tt
                    INNER JOIN tasks t ON t.id = tt.task_id
                    WHERE tt.tag_id = ?
                      AND t.deleted_at IS NULL
                      AND t.is_completed = 0
                    """,
                    arguments: [tag.id]
                ) ?? 0
                return TagSummary(tag: tag, openTaskCount: count)
            }
        }
    }

    func fetch(id: String) throws -> TagRecord? {
        try database.dbQueue.read { db in
            try TagRecord
                .filter(TagRecord.Columns.id == id && TagRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    func fetchTags(forTaskId taskId: String) throws -> [TagRecord] {
        try database.dbQueue.read { db in
            try TagRecord.fetchAll(
                db,
                sql: """
                SELECT g.* FROM tags g
                INNER JOIN task_tags tt ON tt.tag_id = g.id
                WHERE tt.task_id = ?
                  AND g.deleted_at IS NULL
                ORDER BY g.name COLLATE NOCASE ASC
                """,
                arguments: [taskId]
            )
        }
    }

    /// Tags keyed by task id for grouping list rows into soft subheadings.
    func fetchTagsByTaskIds(_ taskIds: [String]) throws -> [String: [TagRecord]] {
        guard !taskIds.isEmpty else { return [:] }
        return try database.dbQueue.read { db in
            let placeholders = Array(repeating: "?", count: taskIds.count).joined(separator: ",")
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT tt.task_id AS task_id, g.*
                FROM tags g
                INNER JOIN task_tags tt ON tt.tag_id = g.id
                WHERE tt.task_id IN (\(placeholders))
                  AND g.deleted_at IS NULL
                ORDER BY g.name COLLATE NOCASE ASC
                """,
                arguments: StatementArguments(taskIds)
            )
            var map: [String: [TagRecord]] = [:]
            for row in rows {
                let taskId: String = row["task_id"]
                // Decode tag columns only (row also carries task_id).
                let tag = TagRecord(
                    id: row["id"],
                    name: row["name"],
                    color: row["color"],
                    createdAt: row["created_at"],
                    updatedAt: row["updated_at"],
                    deletedAt: row["deleted_at"],
                    syncedAt: row["synced_at"]
                )
                map[taskId, default: []].append(tag)
            }
            return map
        }
    }

    /// Non-deleted tasks for a tag, canonical sort (completed last).
    func fetchTasks(tagId: String, includeCompleted: Bool = true) throws -> [TaskRecord] {
        try database.dbQueue.read { db in
            var sql = """
            SELECT t.* FROM tasks t
            INNER JOIN task_tags tt ON tt.task_id = t.id
            INNER JOIN tags g ON g.id = tt.tag_id
            WHERE tt.tag_id = ?
              AND t.deleted_at IS NULL
              AND g.deleted_at IS NULL
            """
            if !includeCompleted {
                sql += " AND t.is_completed = 0"
            }
            sql += " " + TaskOrdering.sqlOrderByClause(includeCompletedBucket: true)
            return try TaskRecord.fetchAll(db, sql: sql, arguments: [tagId])
        }
    }

    // MARK: - Create / update / delete

    @discardableResult
    func create(name: String, color: String? = nil) throws -> TagRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Tag name cannot be empty.")
        }
        try assertNameAvailable(trimmed, excludingId: nil)
        let now = Date()
        let tag = TagRecord(
            id: RecordID.make(),
            name: trimmed,
            color: color,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try tag.insert(db)
        }
        return tag
    }

    @discardableResult
    func rename(id: String, name: String) throws -> TagRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Tag name cannot be empty.")
        }
        try assertNameAvailable(trimmed, excludingId: id)
        return try database.dbQueue.write { db in
            guard var tag = try TagRecord
                .filter(TagRecord.Columns.id == id && TagRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            tag.name = trimmed
            tag.updatedAt = Date()
            try tag.update(db)
            return tag
        }
    }

    func softDelete(id: String) throws {
        try database.dbQueue.write { db in
            guard var tag = try TagRecord
                .filter(TagRecord.Columns.id == id && TagRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let now = Date()
            let linkedTaskIds = try String.fetchAll(
                db,
                sql: "SELECT task_id FROM task_tags WHERE tag_id = ?",
                arguments: [id]
            )
            tag.deletedAt = now
            tag.updatedAt = now
            try tag.update(db)
            try TaskTagRecord
                .filter(TaskTagRecord.Columns.tagId == id)
                .deleteAll(db)
            for taskId in linkedTaskIds {
                if var task = try TaskRecord
                    .filter(TaskRecord.Columns.id == taskId && TaskRecord.Columns.deletedAt == nil)
                    .fetchOne(db)
                {
                    task.updatedAt = now
                    try task.update(db)
                }
            }
        }
    }

    // MARK: - Attach / detach

    func setTags(forTaskId taskId: String, tagIds: [String]) throws {
        let unique = Array(Set(tagIds))
        try database.dbQueue.write { db in
            guard var task = try TaskRecord
                .filter(TaskRecord.Columns.id == taskId && TaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            try TaskTagRecord
                .filter(TaskTagRecord.Columns.taskId == taskId)
                .deleteAll(db)
            let now = Date()
            for tagId in unique {
                guard try TagRecord
                    .filter(TagRecord.Columns.id == tagId && TagRecord.Columns.deletedAt == nil)
                    .fetchOne(db) != nil
                else {
                    continue
                }
                try TaskTagRecord(taskId: taskId, tagId: tagId, createdAt: now).insert(db)
            }
            // Bump parent so SyncEngine pushes task_tags with the task.
            task.updatedAt = now
            try task.update(db)
        }
    }

    func attach(tagId: String, toTaskId taskId: String) throws {
        try database.dbQueue.write { db in
            guard try TagRecord
                .filter(TagRecord.Columns.id == tagId && TagRecord.Columns.deletedAt == nil)
                .fetchOne(db) != nil,
                var task = try TaskRecord
                    .filter(TaskRecord.Columns.id == taskId && TaskRecord.Columns.deletedAt == nil)
                    .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let exists = try TaskTagRecord
                .filter(TaskTagRecord.Columns.taskId == taskId && TaskTagRecord.Columns.tagId == tagId)
                .fetchOne(db) != nil
            guard !exists else { return }
            let now = Date()
            try TaskTagRecord(taskId: taskId, tagId: tagId, createdAt: now).insert(db)
            task.updatedAt = now
            try task.update(db)
        }
    }

    func detach(tagId: String, fromTaskId taskId: String) throws {
        try database.dbQueue.write { db in
            try TaskTagRecord
                .filter(TaskTagRecord.Columns.taskId == taskId && TaskTagRecord.Columns.tagId == tagId)
                .deleteAll(db)
            if var task = try TaskRecord
                .filter(TaskRecord.Columns.id == taskId && TaskRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            {
                task.updatedAt = Date()
                try task.update(db)
            }
        }
    }

    // MARK: - Validation

    private func assertNameAvailable(_ name: String, excludingId: String?) throws {
        try database.dbQueue.read { db in
            var sql = """
            SELECT COUNT(*) FROM tags
            WHERE deleted_at IS NULL AND LOWER(name) = LOWER(?)
            """
            var args: [any DatabaseValueConvertible] = [name]
            if let excludingId {
                sql += " AND id != ?"
                args.append(excludingId)
            }
            let count = try Int.fetchOne(db, sql: sql, arguments: StatementArguments(args)) ?? 0
            if count > 0 {
                throw ServiceError.validation("A tag with that name already exists.")
            }
        }
    }
}
