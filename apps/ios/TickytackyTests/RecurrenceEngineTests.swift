import XCTest
@testable import Tickytacky

final class RecurrenceEngineTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        return calendar.startOfDay(for: calendar.date(from: c)!)
    }

    func testDailyEveryN() {
        let rule = RecurrenceRule(frequency: .daily, interval: 3, startDate: day(2024, 6, 1))
        XCTAssertEqual(
            RecurrenceEngine.nextDate(after: day(2024, 6, 1), rule: rule, calendar: calendar),
            day(2024, 6, 4)
        )
    }

    func testWeekly() {
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, startDate: day(2024, 6, 3))
        XCTAssertEqual(
            RecurrenceEngine.nextDate(after: day(2024, 6, 3), rule: rule, calendar: calendar),
            day(2024, 6, 17)
        )
    }

    func testMonthlyJan31LeapYear() {
        let rule = RecurrenceRule(frequency: .monthly, interval: 1, startDate: day(2024, 1, 31))
        let next = RecurrenceEngine.nextDate(after: day(2024, 1, 31), rule: rule, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: next), 2024)
        XCTAssertEqual(calendar.component(.month, from: next), 2)
        XCTAssertEqual(calendar.component(.day, from: next), 29)
    }

    func testMonthlyJan31NonLeap() {
        let rule = RecurrenceRule(frequency: .monthly, interval: 1, startDate: day(2023, 1, 31))
        let next = RecurrenceEngine.nextDate(after: day(2023, 1, 31), rule: rule, calendar: calendar)
        XCTAssertEqual(calendar.component(.month, from: next), 2)
        XCTAssertEqual(calendar.component(.day, from: next), 28)
    }

    func testYearly() {
        let rule = RecurrenceRule(frequency: .yearly, interval: 1, startDate: day(2024, 2, 29))
        // 2024 → 2025: Feb 29 clamps to Feb 28
        let next = RecurrenceEngine.nextDate(after: day(2024, 2, 29), rule: rule, calendar: calendar)
        XCTAssertEqual(calendar.component(.year, from: next), 2025)
        XCTAssertEqual(calendar.component(.month, from: next), 2)
        XCTAssertEqual(calendar.component(.day, from: next), 28)
    }

    func testOccurrencesDailyWindow() {
        let rule = RecurrenceRule(frequency: .daily, interval: 1, startDate: day(2024, 1, 1))
        let dates = RecurrenceEngine.occurrences(
            from: day(2024, 1, 1),
            to: day(2024, 1, 5),
            rule: rule,
            calendar: calendar
        )
        XCTAssertEqual(dates, [
            day(2024, 1, 1),
            day(2024, 1, 2),
            day(2024, 1, 3),
            day(2024, 1, 4),
        ])
    }

    func testRuleJSONRoundTrip() {
        let start = RecurrenceRuleCoding.parseDay("2024-03-10")!
        let rule = RecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: start,
            byWeekdays: [2, 4]
        )
        let json = rule.jsonString()
        let decoded = RecurrenceRule.from(jsonString: json)
        XCTAssertEqual(decoded?.frequency, .weekly)
        XCTAssertEqual(decoded?.interval, 2)
        XCTAssertEqual(decoded?.byWeekdays, [2, 4])
        XCTAssertEqual(
            RecurrenceRuleCoding.formatDay(decoded!.startDate),
            "2024-03-10"
        )
    }

    #if DEBUG
    func testSelfCheckDoesNotTrap() {
        RecurrenceEngine.runSelfChecks()
    }
    #endif
}
