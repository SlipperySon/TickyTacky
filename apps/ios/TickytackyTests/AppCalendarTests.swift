import XCTest
@testable import Tickytacky

final class AppCalendarTests: XCTestCase {
    func testWeekStartsMonday() {
        XCTAssertEqual(AppCalendar.gregorian.firstWeekday, 2)
        XCTAssertEqual(AppCalendar.locale.identifier, "en_AU")
    }

    func testWeekdayOrderMondayFirst() {
        XCTAssertEqual(AppCalendar.weekdaysMondayFirst.first?.1, "Monday")
        XCTAssertEqual(AppCalendar.weekdaysMondayFirst.last?.1, "Sunday")
        XCTAssertEqual(AppCalendar.veryShortWeekdaySymbolsMondayFirst.count, 7)
        // First symbol should be Monday’s short form under en_AU.
        let mon = AppCalendar.gregorian.veryShortWeekdaySymbols[1]
        XCTAssertEqual(AppCalendar.veryShortWeekdaySymbolsMondayFirst.first, mon)
    }

    func testDayBeforeMonthFormat() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 25
        let date = AppCalendar.gregorian.date(from: comps)!
        let title = AppCalendar.dayTitle.string(from: date)
        // Australian: day number before month abbreviation.
        XCTAssertTrue(title.contains("25"), title)
        XCTAssertFalse(title.hasPrefix("August"), title)
        let dayMonth = AppCalendar.dayMonth.string(from: date)
        XCTAssertEqual(dayMonth, "25 Aug")
    }
}
