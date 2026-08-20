import Foundation

/// Pure inputs for `OccurrenceGenerator` (no GRDB dependency).
struct ScheduleBlockInput: Equatable, Sendable {
    var id: String
    var title: String
    var notes: String?
    /// Calendar weekday: 1 = Sunday … 7 = Saturday.
    var weekday: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var color: String
    var listID: String?
    var reminderMinutesBefore: Int?
}

struct ScheduleExceptionInput: Equatable, Sendable {
    var blockID: String
    var originalStart: Date
    var type: ScheduleExceptionType
    var newStart: Date?
    var newEnd: Date?
}
