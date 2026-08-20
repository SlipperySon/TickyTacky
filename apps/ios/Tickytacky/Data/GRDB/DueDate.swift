import Foundation

/// Helpers for date-only due dates stored as DATETIME start-of-day.
enum DueDate {
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func today(calendar: Calendar = .current) -> Date {
        startOfDay(Date(), calendar: calendar)
    }

    /// Inclusive end of the Upcoming window (start-of-day N days from today).
    static func dayOffset(_ days: Int, from date: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = startOfDay(date, calendar: calendar)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}
