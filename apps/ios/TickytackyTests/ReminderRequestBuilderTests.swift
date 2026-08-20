import XCTest
@testable import Tickytacky

final class ReminderRequestBuilderTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        c.hour = hour
        c.minute = minute
        return calendar.date(from: c)!
    }

    private func sampleTask(
        id: String = "task-1",
        title: String = "Buy milk",
        dueDate: Date?,
        hasDueTime: Bool = false,
        dueHour: Int? = nil,
        dueMinute: Int? = nil,
        offsets: [Int] = [15],
        isCompleted: Bool = false,
        deletedAt: Date? = nil
    ) -> TaskRecord {
        var task = TaskRecord(
            id: id,
            listId: "list-1",
            title: title,
            notes: nil,
            isCompleted: isCompleted,
            completedAt: nil,
            dueDate: dueDate.map { calendar.startOfDay(for: $0) },
            hasDueTime: hasDueTime,
            dueHour: dueHour,
            dueMinute: dueMinute,
            priority: 0,
            sortOrder: 0,
            recurrenceJson: nil,
            reminderOffsetsJson: nil,
            createdAt: date(2024, 1, 1),
            updatedAt: date(2024, 1, 1),
            deletedAt: deletedAt
        )
        task.reminderOffsetsMinutes = offsets
        return task
    }

    func testTaskIdentifierStable() {
        XCTAssertEqual(
            ReminderRequestBuilder.taskIdentifier(taskId: "abc", offsetMinutes: 15),
            "tt.task.abc.15"
        )
    }

    func testBlockIdentifierUsesOriginalStart() {
        let start = date(2024, 6, 10, hour: 9, minute: 30)
        let id = ReminderRequestBuilder.blockIdentifier(
            blockId: "block-1",
            originalStart: start,
            minutesBefore: 10,
            calendar: calendar
        )
        XCTAssertEqual(id, "tt.block.block-1.20240610093000.10")
    }

    func testTaskPlanFireDateWithDueTime() {
        let dueDay = date(2024, 6, 10)
        let now = date(2024, 6, 10, hour: 8, minute: 0)
        let task = sampleTask(
            dueDate: dueDay,
            hasDueTime: true,
            dueHour: 10,
            dueMinute: 0,
            offsets: [15]
        )
        let plans = ReminderRequestBuilder.plans(for: task, now: now, calendar: calendar)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].identifier, "tt.task.task-1.15")
        XCTAssertEqual(plans[0].fireDate, date(2024, 6, 10, hour: 9, minute: 45))
        XCTAssertEqual(plans[0].userInfo[ReminderUserInfoKey.kind], "task")
        XCTAssertEqual(plans[0].userInfo[ReminderUserInfoKey.taskId], "task-1")
    }

    func testDateOnlyUsesNineAM() {
        let dueDay = date(2024, 6, 10)
        let now = date(2024, 6, 9, hour: 12, minute: 0)
        let task = sampleTask(dueDate: dueDay, offsets: [0])
        let plans = ReminderRequestBuilder.plans(for: task, now: now, calendar: calendar)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].fireDate, date(2024, 6, 10, hour: 9, minute: 0))
    }

    func testSkipsCompletedAndDeleted() {
        let dueDay = date(2024, 6, 10)
        let now = date(2024, 6, 9)
        XCTAssertTrue(
            ReminderRequestBuilder.plans(
                for: sampleTask(dueDate: dueDay, isCompleted: true),
                now: now,
                calendar: calendar
            ).isEmpty
        )
        XCTAssertTrue(
            ReminderRequestBuilder.plans(
                for: sampleTask(dueDate: dueDay, deletedAt: now),
                now: now,
                calendar: calendar
            ).isEmpty
        )
    }

    func testSkipsPastFireDates() {
        let dueDay = date(2024, 6, 10)
        let now = date(2024, 6, 10, hour: 10, minute: 0)
        let task = sampleTask(
            dueDate: dueDay,
            hasDueTime: true,
            dueHour: 10,
            dueMinute: 0,
            offsets: [15]
        )
        XCTAssertTrue(ReminderRequestBuilder.plans(for: task, now: now, calendar: calendar).isEmpty)
    }

    func testOccurrencePlan() {
        let start = date(2024, 6, 10, hour: 14, minute: 0)
        let now = date(2024, 6, 10, hour: 12, minute: 0)
        let occurrence = ScheduleOccurrence(
            id: "occ",
            blockID: "block-1",
            title: "Gym",
            notes: nil,
            start: start,
            end: date(2024, 6, 10, hour: 15, minute: 0),
            originalStart: start,
            color: "sage",
            listID: nil,
            isExceptionApplied: false,
            reminderMinutesBefore: 30
        )
        let plans = ReminderRequestBuilder.plans(for: occurrence, now: now, calendar: calendar)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].fireDate, date(2024, 6, 10, hour: 13, minute: 30))
        XCTAssertEqual(plans[0].identifier, "tt.block.block-1.20240610140000.30")
        XCTAssertEqual(plans[0].userInfo[ReminderUserInfoKey.kind], "occurrence")
    }

    func testPrioritizeSoonestWithinBudget() {
        let now = date(2024, 1, 1, hour: 0, minute: 0)
        let plans = (1...10).map { i in
            ReminderPlan(
                identifier: "id-\(i)",
                fireDate: date(2024, 1, 1, hour: i, minute: 0),
                title: "T",
                body: "B",
                userInfo: [:]
            )
        }.reversed()
        let selected = ReminderRequestBuilder.prioritize(Array(plans), now: now, limit: 3)
        XCTAssertEqual(selected.map(\.identifier), ["id-1", "id-2", "id-3"])
    }

    func testDeepLinkRoundTripTask() {
        let link = ReminderDeepLink.task(id: "abc")
        let url = link.url!
        XCTAssertEqual(ReminderDeepLink.parse(url: url), link)
        let info: [AnyHashable: Any] = [
            ReminderUserInfoKey.kind: ReminderDeepLinkKind.task.rawValue,
            ReminderUserInfoKey.taskId: "abc"
        ]
        XCTAssertEqual(ReminderDeepLink.parse(userInfo: info), link)
    }

    func testReminderOffsetsJSONRoundTrip() {
        var task = sampleTask(dueDate: date(2024, 6, 10), offsets: [])
        task.reminderOffsetsMinutes = [60, 15, 15]
        XCTAssertEqual(task.reminderOffsetsMinutes, [15, 60])
        XCTAssertEqual(task.reminderOffsetsJson, "[15,60]")
    }
}
