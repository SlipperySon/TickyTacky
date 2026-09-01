import Foundation

/// Loads timetable occurrences for the calendar bridge publish/pull horizon.
enum CalendarOccurrenceLoader {
    static let horizonWeeks = 8

    static func load(
        database: AppDatabase = .shared,
        calendar: Calendar = AppCalendar.gregorian,
        horizonWeeks: Int = horizonWeeks
    ) throws -> [ScheduleOccurrence] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let diff = (weekday - calendar.firstWeekday + 7) % 7
        guard var weekStart = calendar.date(byAdding: .day, value: -diff, to: today) else { return [] }

        var all: [ScheduleOccurrence] = []
        for _ in 0..<horizonWeeks {
            let week = try database.schedules.occurrences(weekStarting: weekStart, calendar: calendar)
            all.append(contentsOf: week)
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return all
    }

    static func dateRange(
        for occurrences: [ScheduleOccurrence],
        calendar: Calendar = AppCalendar.gregorian,
        horizonWeeks: Int = horizonWeeks
    ) -> (start: Date, end: Date) {
        let now = Date()
        let fallbackStart = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let fallbackEnd = calendar.date(byAdding: .weekOfYear, value: horizonWeeks, to: now) ?? now
        guard let first = occurrences.map(\.start).min(),
              let last = occurrences.map(\.end).max()
        else {
            return (fallbackStart, fallbackEnd)
        }
        return (min(first, fallbackStart), max(last, fallbackEnd))
    }
}
