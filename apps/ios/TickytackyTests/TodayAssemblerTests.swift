import Foundation
import Testing
@testable import Tickytacky

@Suite("TodayAssembler")
struct TodayAssemblerTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
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

    private func task(
        id: String,
        title: String,
        due: Date?,
        priority: Priority = .none,
        hasDueTime: Bool = false,
        dueHour: Int? = nil,
        dueMinute: Int? = nil,
        sortOrder: Int = 0
    ) -> TaskRecord {
        TaskRecord(
            id: id,
            listId: "list",
            title: title,
            notes: nil,
            isCompleted: false,
            completedAt: nil,
            dueDate: due,
            hasDueTime: hasDueTime,
            dueHour: dueHour,
            dueMinute: dueMinute,
            priority: priority.rawValue,
            sortOrder: sortOrder,
            recurrenceJson: nil,
            reminderOffsetsJson: nil,
            createdAt: date(2026, 1, 1),
            updatedAt: date(2026, 1, 1),
            deletedAt: nil
        )
    }

    private func occurrence(
        id: String,
        title: String,
        start: Date,
        end: Date
    ) -> ScheduleOccurrence {
        ScheduleOccurrence(
            id: id,
            blockID: id,
            title: title,
            notes: nil,
            start: start,
            end: end,
            originalStart: start,
            color: "sage",
            listID: nil,
            isExceptionApplied: false,
            reminderMinutesBefore: nil
        )
    }

    @Test func sectionOrderKeepsBucketsSeparate() {
        let overdue = [task(id: "o1", title: "Late", due: date(2026, 8, 17))]
        let dueToday = [task(id: "t1", title: "Today", due: date(2026, 8, 19))]
        let schedule = [
            occurrence(
                id: "s1",
                title: "Class",
                start: date(2026, 8, 19, hour: 9),
                end: date(2026, 8, 19, hour: 10)
            )
        ]

        let snap = TodayAssembler.assemble(
            overdue: overdue,
            dueToday: dueToday,
            occurrences: schedule
        )

        #expect(snap.overdue.map(\.id) == ["o1"])
        #expect(snap.schedule.map(\.id) == ["s1"])
        #expect(snap.dueToday.map(\.id) == ["t1"])
        #expect(!snap.isEmpty)
    }

    @Test func emptyWhenAllInputsEmpty() {
        let snap = TodayAssembler.assemble(overdue: [], dueToday: [], occurrences: [])
        #expect(snap.isEmpty)
    }

    @Test func sortsTasksByPriorityThenDueTimeThenSortOrder() {
        let today = date(2026, 8, 19)
        let unsorted = [
            task(id: "low-late", title: "A", due: today, priority: .low, hasDueTime: true, dueHour: 15, dueMinute: 0, sortOrder: 0),
            task(id: "urgent", title: "B", due: today, priority: .urgent, hasDueTime: true, dueHour: 18, dueMinute: 0, sortOrder: 0),
            task(id: "low-early", title: "C", due: today, priority: .low, hasDueTime: true, dueHour: 9, dueMinute: 0, sortOrder: 0),
            task(id: "low-early-2", title: "D", due: today, priority: .low, hasDueTime: true, dueHour: 9, dueMinute: 0, sortOrder: 1),
            task(id: "low-untimed", title: "E", due: today, priority: .low, hasDueTime: false, sortOrder: 0),
        ]

        let snap = TodayAssembler.assemble(overdue: unsorted, dueToday: unsorted, occurrences: [])

        #expect(snap.overdue.map(\.id) == [
            "urgent",
            "low-early",
            "low-early-2",
            "low-late",
            "low-untimed",
        ])
        #expect(snap.dueToday.map(\.id) == snap.overdue.map(\.id))
    }

    @Test func sortsOccurrencesByStartThenTitle() {
        let unsorted = [
            occurrence(id: "b", title: "Zebra", start: date(2026, 8, 19, hour: 11), end: date(2026, 8, 19, hour: 12)),
            occurrence(id: "a", title: "Alpha", start: date(2026, 8, 19, hour: 9), end: date(2026, 8, 19, hour: 10)),
            occurrence(id: "c", title: "Beta", start: date(2026, 8, 19, hour: 11), end: date(2026, 8, 19, hour: 12)),
        ]

        let snap = TodayAssembler.assemble(overdue: [], dueToday: [], occurrences: unsorted)
        #expect(snap.schedule.map(\.id) == ["a", "c", "b"])
        #expect(snap.schedule.map(\.title) == ["Alpha", "Beta", "Zebra"])
    }

    @Test func scheduleOnlySnapshotIsNotEmpty() {
        let snap = TodayAssembler.assemble(
            overdue: [],
            dueToday: [],
            occurrences: [
                occurrence(
                    id: "s1",
                    title: "Gym",
                    start: date(2026, 8, 19, hour: 7),
                    end: date(2026, 8, 19, hour: 8)
                )
            ]
        )
        #expect(!snap.isEmpty)
        #expect(snap.overdue.isEmpty)
        #expect(snap.dueToday.isEmpty)
        #expect(snap.schedule.count == 1)
    }
}
