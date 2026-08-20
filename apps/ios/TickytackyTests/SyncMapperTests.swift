import XCTest
@testable import Tickytacky

final class SyncMapperTests: XCTestCase {
    func testPriorityRoundTrip() {
        for priority in Priority.allCases {
            let remote = SyncMapper.priorityToRemote(priority.rawValue)
            XCTAssertEqual(SyncMapper.priorityFromRemote(remote), priority.rawValue)
        }
    }

    func testWeekdayRoundTrip() {
        for day in 1...7 {
            let iso = SyncMapper.calendarWeekdayToISO(day)
            XCTAssertEqual(SyncMapper.isoWeekdayToCalendar(iso), day)
        }
        XCTAssertEqual(SyncMapper.calendarWeekdayToISO(1), 7) // Sun → 7
        XCTAssertEqual(SyncMapper.calendarWeekdayToISO(2), 1) // Mon → 1
        XCTAssertEqual(SyncMapper.isoWeekdayToCalendar(7), 1)
        XCTAssertEqual(SyncMapper.isoWeekdayToCalendar(1), 2)
    }

    func testDueDateAndTimeMapping() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = SyncMapper.parseDateOnly("2026-08-19", calendar: cal)!
        let task = TaskRecord(
            id: UUID().uuidString,
            listId: UUID().uuidString,
            title: "Mapped",
            notes: nil,
            isCompleted: false,
            completedAt: nil,
            dueDate: day,
            hasDueTime: true,
            dueHour: 9,
            dueMinute: 30,
            priority: Priority.high.rawValue,
            sortOrder: 0,
            recurrenceJson: nil,
            reminderOffsetsJson: "[15]",
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
        let remote = SyncMapper.toRemote(task: task, userId: UUID().uuidString)
        XCTAssertEqual(remote.due_date, "2026-08-19")
        XCTAssertEqual(remote.due_time, "09:30:00")
        XCTAssertEqual(remote.priority, "high")
        XCTAssertNil(remote.recurrence_frequency)

        let local = SyncMapper.toLocal(task: remote, inboxId: task.listId, preservingRemindersFrom: task)
        XCTAssertEqual(local.hasDueTime, true)
        XCTAssertEqual(local.dueHour, 9)
        XCTAssertEqual(local.dueMinute, 30)
        XCTAssertEqual(local.priority, Priority.high.rawValue)
        XCTAssertEqual(local.reminderOffsetsJson, "[15]", "Reminders stay local-only")
    }

    func testRecurrenceCompactShape() {
        let start = SyncMapper.parseDateOnly("2026-01-05")!
        let rule = RecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: start,
            byWeekdays: [1, 3] // local-only stub; not synced
        )
        let task = TaskRecord(
            id: UUID().uuidString,
            listId: UUID().uuidString,
            title: "Recurring",
            notes: "",
            isCompleted: false,
            completedAt: nil,
            dueDate: nil,
            hasDueTime: false,
            dueHour: nil,
            dueMinute: nil,
            priority: 0,
            sortOrder: 0,
            recurrenceJson: rule.jsonString(),
            reminderOffsetsJson: nil,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
        let remote = SyncMapper.toRemote(task: task, userId: UUID().uuidString)
        XCTAssertEqual(remote.recurrence_frequency, "weekly")
        XCTAssertEqual(remote.recurrence_interval, 2)
        XCTAssertNil(remote.notes, "Empty notes must not be uploaded")

        let nonRecurring = SyncMapper.toRemote(
            task: TaskRecord(
                id: UUID().uuidString,
                listId: task.listId,
                title: "Once",
                notes: nil,
                isCompleted: false,
                completedAt: nil,
                dueDate: nil,
                hasDueTime: false,
                dueHour: nil,
                dueMinute: nil,
                priority: 0,
                sortOrder: 0,
                recurrenceJson: nil,
                reminderOffsetsJson: nil,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil
            ),
            userId: UUID().uuidString
        )
        XCTAssertNil(nonRecurring.recurrence_frequency)
        XCTAssertNil(nonRecurring.recurrence_interval)
        XCTAssertNil(nonRecurring.recurrence_start)

        let local = SyncMapper.toLocal(task: remote, inboxId: task.listId)
        XCTAssertEqual(local.recurrenceRule?.frequency, .weekly)
        XCTAssertEqual(local.recurrenceRule?.interval, 2)
        XCTAssertNil(local.recurrenceRule?.byWeekdays)
    }

    func testScheduleBlockWeekdayAndTime() {
        let block = ScheduleBlockRecord(
            id: UUID().uuidString,
            scheduleId: UUID().uuidString,
            title: "Class",
            notes: nil,
            weekday: 2, // Monday local
            startHour: 10,
            startMinute: 15,
            endHour: 11,
            endMinute: 0,
            color: "sage",
            listId: nil,
            reminderMinutesBefore: 5,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
        let remote = SyncMapper.toRemote(block: block, userId: UUID().uuidString)
        XCTAssertEqual(remote.iso_weekday, 1)
        XCTAssertEqual(remote.start_time, "10:15:00")
        XCTAssertEqual(remote.end_time, "11:00:00")

        var remoteNilColor = remote
        remoteNilColor.color = nil
        let local = SyncMapper.toLocal(block: remoteNilColor)
        XCTAssertEqual(local.weekday, 2)
        XCTAssertEqual(local.color, "sage")
    }

    func testDirtyDetection() {
        let now = Date()
        XCTAssertTrue(SyncMapper.isDirty(updatedAt: now, syncedAt: nil))
        XCTAssertTrue(SyncMapper.isDirty(updatedAt: now, syncedAt: now.addingTimeInterval(-10)))
        XCTAssertFalse(SyncMapper.isDirty(updatedAt: now, syncedAt: now))
    }

    func testShouldApplyRemoteNeverClobbersDirtyLocal() {
        let now = Date()
        let older = now.addingTimeInterval(-60)
        let newer = now.addingTimeInterval(60)

        // Dirty local (syncedAt behind updatedAt) — never apply remote, even if remote is newer.
        XCTAssertFalse(
            SyncEngine.shouldApplyRemote(
                localUpdated: now,
                localSynced: older,
                remoteUpdated: newer
            )
        )
        XCTAssertFalse(
            SyncEngine.shouldApplyRemote(
                localUpdated: now,
                localSynced: nil,
                remoteUpdated: older
            )
        )

        // Clean local newer than remote — keep local.
        XCTAssertFalse(
            SyncEngine.shouldApplyRemote(
                localUpdated: newer,
                localSynced: newer,
                remoteUpdated: now
            )
        )

        // Clean local equal/older — apply remote.
        XCTAssertTrue(
            SyncEngine.shouldApplyRemote(
                localUpdated: now,
                localSynced: now,
                remoteUpdated: newer
            )
        )
        XCTAssertTrue(
            SyncEngine.shouldApplyRemote(
                localUpdated: now,
                localSynced: now,
                remoteUpdated: now
            )
        )

        // No local row — apply remote.
        XCTAssertTrue(
            SyncEngine.shouldApplyRemote(
                localUpdated: nil,
                localSynced: nil,
                remoteUpdated: now
            )
        )
    }

    func testRecordIDNormalizeInMapper() {
        let upper = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        let list = TaskListRecord(
            id: upper,
            name: "Inbox",
            color: nil,
            icon: nil,
            sortOrder: 0,
            isInbox: true,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
        let remote = SyncMapper.toRemote(list: list, userId: "user")
        XCTAssertEqual(remote.id, upper.lowercased())
        let local = SyncMapper.toLocal(list: remote)
        XCTAssertEqual(local.id, upper.lowercased())
    }
}
