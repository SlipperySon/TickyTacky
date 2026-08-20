import Foundation

// MARK: - Remote DTOs (match supabase/migrations snake_case)

struct RemoteList: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var name: String
    var color: String?
    var is_inbox: Bool
    var sort_order: Int
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct RemoteTag: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var name: String
    var color: String?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct RemoteTask: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var list_id: String?
    var title: String
    var notes: String?
    var is_completed: Bool
    var completed_at: Date?
    var due_date: String?
    var due_time: String?
    var priority: String
    var sort_order: Int
    var recurrence_frequency: String?
    /// Null when non-recurring (cloud storage compact).
    var recurrence_interval: Int?
    var recurrence_start: String?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct RemoteSubtask: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var task_id: String
    var title: String
    var is_completed: Bool
    var sort_order: Int
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct RemoteTaskTag: Codable, Sendable, Equatable {
    var task_id: String
    var tag_id: String
    var user_id: String
    var created_at: Date
}

struct RemoteSchedule: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var name: String
    var is_active: Bool
    var color: String?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct RemoteScheduleBlock: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var schedule_id: String
    var title: String
    var notes: String?
    var iso_weekday: Int
    var start_time: String
    var end_time: String
    var color: String?
    var list_id: String?
    var reminder_minutes_before: Int?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct RemoteScheduleException: Codable, Sendable, Equatable {
    var id: String
    var user_id: String
    var block_id: String
    var original_start: Date
    var type: String
    var new_start: Date?
    var new_end: Date?
    var notes: String?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}
