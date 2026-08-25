import Foundation
import GRDB

/// List CRUD against the local GRDB cache. Soft-delete only.
final class ListService: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    struct ListSummary: Equatable, Identifiable, Sendable {
        var list: TaskListRecord
        var openTaskCount: Int
        var id: String { list.id }
    }

    func fetchAll() throws -> [TaskListRecord] {
        try database.dbQueue.read { db in
            try TaskListRecord
                .filter(TaskListRecord.Columns.deletedAt == nil)
                .order(TaskListRecord.Columns.isInbox.desc, TaskListRecord.Columns.sortOrder, TaskListRecord.Columns.name)
                .fetchAll(db)
        }
    }

    func fetchSummaries() throws -> [ListSummary] {
        try database.dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT l.*, COALESCE(c.open_count, 0) AS open_count
                FROM lists l
                LEFT JOIN (
                    SELECT list_id, COUNT(*) AS open_count
                    FROM tasks
                    WHERE deleted_at IS NULL AND is_completed = 0
                    GROUP BY list_id
                ) c ON c.list_id = l.id
                WHERE l.deleted_at IS NULL
                ORDER BY l.is_inbox DESC, l.sort_order ASC, l.name COLLATE NOCASE ASC
                """
            )
            return rows.map { row in
                ListSummary(
                    list: TaskListRecord(
                        id: row["id"],
                        name: row["name"],
                        color: row["color"],
                        icon: row["icon"],
                        sortOrder: row["sort_order"],
                        isInbox: row["is_inbox"],
                        createdAt: row["created_at"],
                        updatedAt: row["updated_at"],
                        deletedAt: row["deleted_at"],
                        syncedAt: row["synced_at"]
                    ),
                    openTaskCount: row["open_count"]
                )
            }
        }
    }

    func fetch(id: String) throws -> TaskListRecord? {
        try database.dbQueue.read { db in
            try TaskListRecord
                .filter(TaskListRecord.Columns.id == id && TaskListRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    @discardableResult
    func create(name: String, color: String? = nil, icon: String? = nil) throws -> TaskListRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("List name cannot be empty.")
        }
        let now = Date()
        let maxOrder = try database.dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sort_order), 0) FROM lists WHERE deleted_at IS NULL AND is_inbox = 0"
            ) ?? 0
        }
        let list = TaskListRecord(
            id: RecordID.make(),
            name: trimmed,
            color: color,
            icon: icon,
            sortOrder: maxOrder + 1,
            isInbox: false,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try list.insert(db)
        }
        return list
    }

    @discardableResult
    func rename(id: String, name: String) throws -> TaskListRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("List name cannot be empty.")
        }
        return try database.dbQueue.write { db in
            guard var list = try TaskListRecord
                .filter(TaskListRecord.Columns.id == id && TaskListRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            list.name = trimmed
            list.updatedAt = Date()
            try list.update(db)
            return list
        }
    }

    /// Soft-deletes a non-inbox list and moves its open tasks to Inbox.
    func delete(id: String) throws {
        try database.dbQueue.write { db in
            guard var list = try TaskListRecord
                .filter(TaskListRecord.Columns.id == id && TaskListRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            guard !list.isInbox else {
                throw ServiceError.validation("Inbox cannot be deleted.")
            }
            guard let inbox = try TaskListRecord
                .filter(TaskListRecord.Columns.isInbox == true && TaskListRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let now = Date()
            try db.execute(
                sql: """
                UPDATE tasks SET list_id = ?, updated_at = ?
                WHERE list_id = ? AND deleted_at IS NULL
                """,
                arguments: [inbox.id, now, id]
            )
            list.deletedAt = now
            list.updatedAt = now
            try list.update(db)
        }
    }
}
