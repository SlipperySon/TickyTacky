import Foundation
import GRDB

#if DEBUG
/// Inserts a rich local dataset for UI / calendar / focus dogfooding.
/// Few lists (Inbox + Life + Groceries); context via tags + Group by tag.
enum DebugSampleSeeder {
    private static let defaultsKey = "debug.sampleDataVersion"
    private static let version = 2

    static func seedIfNeeded(database: AppDatabase) {
        guard UserDefaults.standard.integer(forKey: defaultsKey) < version else { return }
        do {
            let count = try database.dbQueue.read { db in
                try TaskRecord
                    .filter(TaskRecord.Columns.deletedAt == nil)
                    .fetchCount(db)
            }
            guard count == 0 else {
                UserDefaults.standard.set(version, forKey: defaultsKey)
                return
            }
            try seed(database: database)
            UserDefaults.standard.set(version, forKey: defaultsKey)
        } catch {
            assertionFailure("Sample seed failed: \(error)")
        }
    }

    /// Always inserts a fresh sample batch (safe to call repeatedly).
    @discardableResult
    static func seed(database: AppDatabase) throws -> String {
        UserDefaults.standard.set(true, forKey: "list.groupByTag")

        let lists = ListService(database: database)
        let tags = TagService(database: database)
        let tasks = TaskService(database: database)
        let schedule = ScheduleService(database: database)
        let cal = Calendar.current
        let today = DueDate.startOfDay(Date())

        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: today) ?? today
        }

        func tagNamed(_ name: String, color: PastelSwatch, from existing: [TagRecord]) throws -> TagRecord {
            if let found = existing.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                return found
            }
            return try tags.create(name: name, color: color.rawValue)
        }

        guard let inbox = try database.fetchInbox() else {
            throw ServiceError.notFound
        }

        // Minimal lists: Life (everything) + Groceries (checklist). Prefer tags over more lists.
        let allLists = try lists.fetchAll()
        let life: TaskListRecord
        if let existing = allLists.first(where: {
            !$0.isInbox && ($0.name == "Life" || $0.name == "Personal")
        }) {
            life = existing
        } else {
            life = try lists.create(name: "Life", color: PastelSwatch.blush.rawValue, icon: "heart")
        }
        let groceries: TaskListRecord
        if let existing = allLists.first(where: { GroceryMode.isGroceryListName($0.name) && !$0.isInbox }) {
            groceries = existing
        } else {
            groceries = try lists.create(name: "Groceries", color: PastelSwatch.mist.rawValue, icon: "cart")
        }

        var allTags = try tags.fetchAll()
        let workTag = try tagNamed("Work", color: .sage, from: allTags)
        allTags.append(workTag)
        let urgent = try tagNamed("Urgent", color: .kraft, from: allTags)
        allTags.append(urgent)
        let waiting = try tagNamed("Waiting", color: .lilac, from: allTags)
        allTags.append(waiting)
        let home = try tagNamed("Home", color: .mist, from: allTags)
        allTags.append(home)
        let mathTag = try tagNamed("MATH101", color: .sky, from: allTags)
        allTags.append(mathTag)
        let histTag = try tagNamed("HIST200", color: .blush, from: allTags)

        let packReview = try tasks.create(
            title: "Review Q3 roadmap",
            listId: life.id,
            notes: "Sample: tagged Work — Group by tag shows it under Work.",
            dueDate: day(-2),
            hasDueTime: true,
            dueHour: 10,
            dueMinute: 0,
            priority: .high
        )
        try tags.setTags(forTaskId: packReview.id, tagIds: [workTag.id, urgent.id])

        let email = try tasks.create(
            title: "Email design feedback",
            listId: life.id,
            dueDate: day(-1),
            priority: .medium
        )
        try tags.setTags(forTaskId: email.id, tagIds: [workTag.id])

        let standupPrep = try tasks.create(
            title: "Prep standup notes",
            listId: life.id,
            notes: "Sample task due this morning.",
            dueDate: today,
            hasDueTime: true,
            dueHour: 9,
            dueMinute: 0,
            priority: .high
        )
        try tags.setTags(forTaskId: standupPrep.id, tagIds: [workTag.id, urgent.id])

        // Nudge demo: grocery keyword on Life list
        let buyGroceriesTask = try tasks.create(
            title: "Buy groceries",
            listId: life.id,
            notes: "Open this task to see the Move to Groceries nudge.",
            dueDate: today,
            hasDueTime: true,
            dueHour: 17,
            dueMinute: 30,
            priority: .medium
        )
        try tags.setTags(forTaskId: buyGroceriesTask.id, tagIds: [home.id])

        for item in ["Milk", "Eggs", "Sourdough", "Coffee beans"] {
            _ = try tasks.create(title: item, listId: groceries.id)
        }

        let problemSet = try tasks.create(
            title: "Problem set 4",
            listId: life.id,
            dueDate: day(3),
            priority: .high
        )
        try tags.setTags(forTaskId: problemSet.id, tagIds: [mathTag.id])

        let essayOutline = try tasks.create(
            title: "Essay outline",
            listId: life.id,
            dueDate: day(5),
            priority: .medium
        )
        try tags.setTags(forTaskId: essayOutline.id, tagIds: [histTag.id])

        let officeHours = try tasks.create(
            title: "Book office hours",
            listId: life.id,
            dueDate: day(1),
            priority: .low
        )
        try tags.setTags(forTaskId: officeHours.id, tagIds: [mathTag.id])

        _ = try tasks.create(
            title: "Call the dentist",
            listId: life.id,
            dueDate: today,
            priority: .low
        )

        _ = try tasks.create(
            title: "Inbox triage",
            listId: inbox.id,
            notes: "Sample untimed inbox item.",
            priority: .none
        )

        var weeklyReview = try tasks.create(
            title: "Weekly planning",
            listId: life.id,
            dueDate: day(1),
            hasDueTime: true,
            dueHour: 9,
            dueMinute: 30,
            priority: .medium
        )
        weeklyReview.recurrenceJson = RecurrenceRule(
            frequency: .weekly,
            interval: 1,
            startDate: day(1),
            byWeekdays: [cal.component(.weekday, from: day(1))]
        ).jsonString()
        weeklyReview.reminderOffsetsMinutes = [0, 30]
        _ = try tasks.update(weeklyReview)
        try tags.setTags(forTaskId: weeklyReview.id, tagIds: [workTag.id])

        let ship = try tasks.create(
            title: "Ship TestFlight build",
            listId: life.id,
            dueDate: day(2),
            hasDueTime: true,
            dueHour: 14,
            dueMinute: 0,
            priority: .urgent
        )
        try tags.setTags(forTaskId: ship.id, tagIds: [workTag.id, urgent.id, waiting.id])

        let hike = try tasks.create(
            title: "Plan weekend hike",
            listId: life.id,
            dueDate: day(4),
            priority: .low
        )
        try tags.setTags(forTaskId: hike.id, tagIds: [home.id])

        _ = try tasks.create(
            title: "Renew domain",
            listId: life.id,
            dueDate: day(10),
            priority: .medium
        )

        let expense = try tasks.create(
            title: "File expense report",
            listId: life.id,
            dueDate: day(-3),
            priority: .medium
        )
        try tags.setTags(forTaskId: expense.id, tagIds: [workTag.id])
        _ = try tasks.setCompleted(id: expense.id, completed: true)

        let sched = try schedule.ensureDefaultSchedule()
        let existingBlocks = try schedule.fetchBlocks(scheduleId: sched.id)
        if existingBlocks.isEmpty {
            let weekdayBlocks: [(title: String, start: (Int, Int), end: (Int, Int), color: PastelSwatch, list: String?)] = [
                ("Deep work", (9, 0), (11, 0), .sage, life.id),
                ("Standup", (11, 0), (11, 30), .sky, life.id),
                ("Lunch", (12, 30), (13, 30), .butter, nil),
                ("Focus block", (14, 0), (16, 0), .lilac, life.id),
                ("Wrap-up", (16, 30), (17, 0), .mist, life.id),
            ]
            for weekday in 2...6 {
                for b in weekdayBlocks {
                    _ = try schedule.createBlock(
                        scheduleId: sched.id,
                        title: b.title,
                        notes: "Sample schedule block",
                        weekday: weekday,
                        startHour: b.start.0,
                        startMinute: b.start.1,
                        endHour: b.end.0,
                        endMinute: b.end.1,
                        color: b.color.rawValue,
                        listId: b.list,
                        reminderMinutesBefore: b.title == "Standup" ? 5 : nil
                    )
                }
            }
            _ = try schedule.createBlock(
                scheduleId: sched.id,
                title: "Gym",
                weekday: 7,
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 30,
                color: PastelSwatch.kraft.rawValue,
                listId: life.id
            )
            _ = try schedule.createBlock(
                scheduleId: sched.id,
                title: "Family brunch",
                weekday: 1,
                startHour: 11,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                color: PastelSwatch.blush.rawValue,
                listId: life.id
            )
            let todayWeekday = cal.component(.weekday, from: today)
            if (2...6).contains(todayWeekday) {
                _ = try schedule.createBlock(
                    scheduleId: sched.id,
                    title: "1:1 (overlap sample)",
                    notes: "Overlaps Focus block on purpose",
                    weekday: todayWeekday,
                    startHour: 14,
                    startMinute: 30,
                    endHour: 15,
                    endMinute: 30,
                    color: PastelSwatch.butter.rawValue,
                    listId: life.id
                )
            }
        }

        let end = Date()
        let start = end.addingTimeInterval(-25 * 60)
        let session = FocusSessionRecord(
            id: RecordID.make(),
            taskId: standupPrep.id,
            kind: FocusSessionKind.work.rawValue,
            plannedSeconds: 25 * 60,
            startedAt: start,
            endedAt: end,
            completedAt: end,
            createdAt: start,
            updatedAt: end,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try session.insert(db)
        }

        NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
        Task {
            await ReminderScheduler.shared.refresh(database: database)
        }

        return "Sample data: Life + Groceries lists, tags (Work, MATH101…), timetable, focus session."
    }
}
#endif
