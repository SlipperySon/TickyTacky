import Foundation
import GRDB

/// Title/notes contains search against the local GRDB cache.
final class SearchService: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    /// Case-insensitive substring match on `title` and `notes`. Empty query → [].
    func searchTasks(query: String, limit: Int = 100) throws -> [TaskRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let pattern = "%\(escapeLike(trimmed))%"
        return try database.dbQueue.read { db in
            try TaskRecord.fetchAll(
                db,
                sql: """
                SELECT * FROM tasks
                WHERE deleted_at IS NULL
                  AND (
                    title LIKE ? ESCAPE '\\'
                    OR IFNULL(notes, '') LIKE ? ESCAPE '\\'
                  )
                \(TaskOrdering.sqlOrderByClause(includeCompletedBucket: true, tableAlias: ""))
                LIMIT ?
                """,
                arguments: [pattern, pattern, limit]
            )
        }
    }

    private func escapeLike(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
