import Foundation
import Testing
@testable import Tickytacky

@Suite("OccurrenceGenerator")
struct OccurrenceGeneratorTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    /// 2026-08-17 is a Monday (weekday 2).
    @Test func expandsWeeklyBlockOntoMatchingWeekdays() {
        let block = ScheduleBlockInput(
            id: "b1",
            title: "Deep Work",
            weekday: 2,
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 30,
            color: "sage"
        )
        let from = date(2026, 8, 17)
        let to = date(2026, 8, 24)
        let result = OccurrenceGenerator.occurrences(
            blocks: [block],
            exceptions: [],
            from: from,
            to: to,
            calendar: calendar
        )
        #expect(result.count == 1)
        #expect(result[0].title == "Deep Work")
        #expect(result[0].start == date(2026, 8, 17, hour: 9))
        #expect(result[0].end == date(2026, 8, 17, hour: 10, minute: 30))
        #expect(result[0].isExceptionApplied == false)
    }

    @Test func skipExceptionOmitsOccurrence() {
        let block = ScheduleBlockInput(
            id: "b1",
            title: "Class",
            weekday: 3,
            startHour: 14,
            startMinute: 0,
            endHour: 15,
            endMinute: 0,
            color: "sky"
        )
        let original = date(2026, 8, 18, hour: 14) // Tuesday
        let result = OccurrenceGenerator.occurrences(
            blocks: [block],
            exceptions: [
                ScheduleExceptionInput(blockID: "b1", originalStart: original, type: .skip)
            ],
            from: date(2026, 8, 17),
            to: date(2026, 8, 24),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func rescheduleMovesOccurrence() {
        let block = ScheduleBlockInput(
            id: "b1",
            title: "Lab",
            weekday: 4,
            startHour: 11,
            startMinute: 0,
            endHour: 12,
            endMinute: 0,
            color: "lilac"
        )
        let original = date(2026, 8, 19, hour: 11) // Wednesday
        let newStart = date(2026, 8, 19, hour: 16)
        let newEnd = date(2026, 8, 19, hour: 17)
        let result = OccurrenceGenerator.occurrences(
            blocks: [block],
            exceptions: [
                ScheduleExceptionInput(
                    blockID: "b1",
                    originalStart: original,
                    type: .reschedule,
                    newStart: newStart,
                    newEnd: newEnd
                )
            ],
            from: date(2026, 8, 17),
            to: date(2026, 8, 24),
            calendar: calendar
        )
        #expect(result.count == 1)
        #expect(result[0].start == newStart)
        #expect(result[0].end == newEnd)
        #expect(result[0].originalStart == original)
        #expect(result[0].isExceptionApplied == true)
    }

    @Test func rescheduleIntoDifferentWeekAppearsInTargetRange() {
        // Monday block in week of Aug 17; rescheduled into the following Monday (Aug 24).
        let block = ScheduleBlockInput(
            id: "b1",
            title: "Deep Work",
            weekday: 2,
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 30,
            color: "sage"
        )
        let original = date(2026, 8, 17, hour: 9)
        let newStart = date(2026, 8, 24, hour: 14)
        let newEnd = date(2026, 8, 24, hour: 15, minute: 30)
        let result = OccurrenceGenerator.occurrences(
            blocks: [block],
            exceptions: [
                ScheduleExceptionInput(
                    blockID: "b1",
                    originalStart: original,
                    type: .reschedule,
                    newStart: newStart,
                    newEnd: newEnd
                )
            ],
            from: date(2026, 8, 24),
            to: date(2026, 8, 31),
            calendar: calendar
        )
        #expect(result.count == 2) // regular Mon 24 slot + reschedule from prior week
        let moved = result.first { $0.isExceptionApplied }
        #expect(moved != nil)
        #expect(moved?.start == newStart)
        #expect(moved?.end == newEnd)
        #expect(moved?.originalStart == original)
        #expect(moved?.title == "Deep Work")
    }

    @Test func sortsByStartThenTitle() {
        let a = ScheduleBlockInput(
            id: "a",
            title: "Beta",
            weekday: 2,
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 0,
            color: "sage"
        )
        let b = ScheduleBlockInput(
            id: "b",
            title: "Alpha",
            weekday: 2,
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 0,
            color: "sky"
        )
        let result = OccurrenceGenerator.occurrences(
            blocks: [a, b],
            exceptions: [],
            from: date(2026, 8, 17),
            to: date(2026, 8, 18),
            calendar: calendar
        )
        #expect(result.map(\.title) == ["Alpha", "Beta"])
    }
}

@Suite("ScheduleBlockValidation")
struct ScheduleBlockValidationTests {
    @Test func rejectsEndBeforeOrEqualStart() {
        #expect(throws: (any Error).self) {
            try ScheduleBlockValidation.validate(
                startHour: 10,
                startMinute: 0,
                endHour: 9,
                endMinute: 0
            )
        }
        #expect(throws: (any Error).self) {
            try ScheduleBlockValidation.validate(
                startHour: 10,
                startMinute: 0,
                endHour: 10,
                endMinute: 0
            )
        }
    }

    @Test func acceptsSameDayRange() throws {
        try ScheduleBlockValidation.validate(
            startHour: 9,
            startMinute: 0,
            endHour: 10,
            endMinute: 30
        )
    }
}
