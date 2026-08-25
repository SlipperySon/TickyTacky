import Foundation
import GRDB

enum FocusSessionKind: Int, Codable, Sendable, CaseIterable, Identifiable {
    case work = 0
    case shortBreak = 1
    case longBreak = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .work: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }

    var isBreak: Bool {
        self != .work
    }
}

/// Local Pomodoro / focus session. Not synced in MVP.
struct FocusSessionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable, Sendable {
    static let databaseTableName = "focus_sessions"

    var id: String
    var taskId: String?
    var kind: Int
    var plannedSeconds: Int
    var startedAt: Date
    var endedAt: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    enum Columns: String, ColumnExpression {
        case id, kind
        case taskId = "task_id"
        case plannedSeconds = "planned_seconds"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, kind
        case taskId = "task_id"
        case plannedSeconds = "planned_seconds"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    var kindValue: FocusSessionKind {
        get { FocusSessionKind(rawValue: kind) ?? .work }
        set { kind = newValue.rawValue }
    }

    var didComplete: Bool { completedAt != nil }
}
