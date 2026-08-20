import Foundation

/// Computed timetable slot produced by `OccurrenceGenerator` (not persisted).
struct ScheduleOccurrence: Equatable, Identifiable, Sendable {
    /// Stable id: `blockID|originalStart` (ISO8601).
    var id: String
    var blockID: String
    var title: String
    var notes: String?
    var start: Date
    var end: Date
    /// Series occurrence start before exception move (identity for skip/reschedule).
    var originalStart: Date
    var color: String
    var listID: String?
    var isExceptionApplied: Bool
    var reminderMinutesBefore: Int?

    static func makeID(blockID: String, originalStart: Date) -> String {
        "\(blockID)|\(ISO8601DateFormatter().string(from: originalStart))"
    }
}
