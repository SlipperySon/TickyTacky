import Foundation
import GRDB

/// Focus / Pomodoro session CRUD against the local GRDB cache.
final class FocusService: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func fetch(id: String) throws -> FocusSessionRecord? {
        try database.dbQueue.read { db in
            try FocusSessionRecord
                .filter(FocusSessionRecord.Columns.id == id && FocusSessionRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    func fetchToday(calendar: Calendar = .current) throws -> [FocusSessionRecord] {
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try database.dbQueue.read { db in
            try FocusSessionRecord
                .filter(
                    FocusSessionRecord.Columns.deletedAt == nil
                        && FocusSessionRecord.Columns.startedAt >= start
                        && FocusSessionRecord.Columns.startedAt < end
                )
                .order(FocusSessionRecord.Columns.startedAt.desc)
                .fetchAll(db)
        }
    }

    func completedWorkCountToday(calendar: Calendar = .current) throws -> Int {
        try fetchToday(calendar: calendar)
            .filter { $0.kindValue == .work && $0.didComplete }
            .count
    }

    @discardableResult
    func start(
        kind: FocusSessionKind,
        plannedSeconds: Int,
        taskId: String?
    ) throws -> FocusSessionRecord {
        let now = Date()
        let session = FocusSessionRecord(
            id: RecordID.make(),
            taskId: taskId.map(RecordID.normalize),
            kind: kind.rawValue,
            plannedSeconds: max(1, plannedSeconds),
            startedAt: now,
            endedAt: nil,
            completedAt: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try session.insert(db)
        }
        return session
    }

    func markCompleted(id: String, at date: Date = Date()) throws {
        try database.dbQueue.write { db in
            guard var row = try FocusSessionRecord
                .filter(FocusSessionRecord.Columns.id == id && FocusSessionRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else { return }
            row.completedAt = date
            row.endedAt = date
            row.updatedAt = date
            try row.update(db)
        }
    }

    func markEnded(id: String, at date: Date = Date()) throws {
        try database.dbQueue.write { db in
            guard var row = try FocusSessionRecord
                .filter(FocusSessionRecord.Columns.id == id && FocusSessionRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else { return }
            if row.endedAt == nil {
                row.endedAt = date
            }
            row.updatedAt = date
            try row.update(db)
        }
    }
}
