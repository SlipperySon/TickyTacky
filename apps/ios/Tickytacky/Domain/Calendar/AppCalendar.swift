import Foundation

/// Australian calendar conventions for Tickytacky UI (not US defaults).
enum AppCalendar {
    /// `en_AU` — day/month ordering, Australian English.
    static let locale = Locale(identifier: "en_AU")

    /// Gregorian calendar, week starts **Monday** (ISO / AU norm).
    static var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.firstWeekday = 2 // Monday
        calendar.timeZone = .current
        return calendar
    }

    // MARK: - Formatters (day before month; AU locale)

    static let weekdayShort: DateFormatter = {
        makeFormatter(dateFormat: "EEE")
    }()

    static let dayOfMonth: DateFormatter = {
        makeFormatter(dateFormat: "d")
    }()

    /// e.g. Monday, 25 Aug
    static let dayTitle: DateFormatter = {
        makeFormatter(dateFormat: "EEEE, d MMM")
    }()

    /// e.g. 25 Aug
    static let dayMonth: DateFormatter = {
        makeFormatter(dateFormat: "d MMM")
    }()

    /// e.g. August 2026
    static let monthYear: DateFormatter = {
        makeFormatter(dateFormat: "MMMM yyyy")
    }()

    /// e.g. 9:00 am (en_AU)
    static let timeShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = gregorian
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// Weekday picker order: Monday → Sunday (Calendar weekday ints).
    static let weekdaysMondayFirst: [(Int, String)] = [
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday"),
        (1, "Sunday"),
    ]

    /// Rotated very-short weekday symbols starting Monday.
    static var veryShortWeekdaySymbolsMondayFirst: [String] {
        let symbols = gregorian.veryShortWeekdaySymbols // Sun…Sat in Foundation order
        let first = gregorian.firstWeekday - 1 // 1 → index 1 = Mon
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private static func makeFormatter(dateFormat: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = gregorian
        f.dateFormat = dateFormat
        return f
    }
}
