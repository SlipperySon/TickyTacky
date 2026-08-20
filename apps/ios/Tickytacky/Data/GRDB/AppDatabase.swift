import Foundation
import GRDB

/// Local SQLite cache. Supabase remains source of truth once sync lands (Phase H).
final class AppDatabase: @unchecked Sendable {
    static let shared = makeShared()

    let dbQueue: DatabaseQueue

    private init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    private static func makeShared() -> AppDatabase {
        do {
            return try openFresh()
        } catch {
            // One-shot recovery for corrupt / half-migrated caches (seen as launch fatalError).
            if let dbURL = try? databaseURL() {
                try? FileManager.default.removeItem(at: dbURL)
            }
            do {
                return try openFresh()
            } catch {
                fatalError("Failed to open AppDatabase: \(error)")
            }
        }
    }

    private static func databaseURL() throws -> URL {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Tickytacky", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("cache.sqlite")
    }

    private static func openFresh() throws -> AppDatabase {
        let dbURL = try databaseURL()
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
        var migrator = DatabaseMigrator()
        AppMigrations.register(&migrator)
        try migrator.migrate(dbQueue)
        let appDB = AppDatabase(dbQueue: dbQueue)
        try appDB.seedInboxIfNeeded()
        _ = try appDB.schedules.ensureDefaultSchedule()
        return appDB
    }

    func seedInboxIfNeeded() throws {
        try dbQueue.write { db in
            let inboxExists = try TaskListRecord
                .filter(TaskListRecord.Columns.isInbox == true && TaskListRecord.Columns.deletedAt == nil)
                .fetchOne(db) != nil
            guard !inboxExists else { return }
            let now = Date()
            let inbox = TaskListRecord(
                id: RecordID.make(),
                name: "Inbox",
                color: "sage",
                icon: nil,
                sortOrder: 0,
                isInbox: true,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            try inbox.insert(db)
        }
    }

    /// Wipe domain rows when switching signed-in accounts.
    func resetUserData() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM schedule_exceptions")
            try db.execute(sql: "DELETE FROM schedule_blocks")
            try db.execute(sql: "DELETE FROM schedules")
            try db.execute(sql: "DELETE FROM task_tags")
            try db.execute(sql: "DELETE FROM subtasks")
            try db.execute(sql: "DELETE FROM tasks")
            try db.execute(sql: "DELETE FROM tags")
            try db.execute(sql: "DELETE FROM lists")
            try db.execute(sql: "DELETE FROM sync_meta")
        }
        try seedInboxIfNeeded()
        _ = try schedules.ensureDefaultSchedule()
    }

    func fetchInbox() throws -> TaskListRecord? {
        try dbQueue.read { db in
            try TaskListRecord
                .filter(TaskListRecord.Columns.isInbox == true && TaskListRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    var lists: ListService { ListService(database: self) }
    var tasks: TaskService { TaskService(database: self) }
    var tags: TagService { TagService(database: self) }
    var search: SearchService { SearchService(database: self) }
    var schedules: ScheduleService { ScheduleService(database: self) }
}
