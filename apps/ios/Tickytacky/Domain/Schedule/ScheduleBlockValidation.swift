import Foundation

/// Validates schedule block time ranges for MVP (same-day only, end after start).
enum ScheduleBlockValidation {
    static func validate(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) throws {
        guard (0...23).contains(startHour), (0...59).contains(startMinute),
              (0...23).contains(endHour), (0...59).contains(endMinute)
        else {
            throw ServiceError.validation("Invalid time components.")
        }
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        guard end > start else {
            throw ServiceError.validation("End time must be after start time.")
        }
        // Overnight / midnight-spanning not supported in MVP.
        // (Already implied by end > start on same day; keep explicit for clarity.)
    }

    static func validateWeekday(_ weekday: Int) throws {
        guard (1...7).contains(weekday) else {
            throw ServiceError.validation("Weekday must be 1 (Sunday) through 7 (Saturday).")
        }
    }
}
