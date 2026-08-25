import XCTest
@testable import Tickytacky

final class TagGroupingTests: XCTestCase {
    func testPrimaryPrefersContextOverMeta() {
        let urgent = tag(id: "1", name: "Urgent")
        let math = tag(id: "2", name: "MATH101")
        let primary = TagGrouping.primaryTag(from: [urgent, math])
        XCTAssertEqual(primary?.id, math.id)
    }

    func testSectionsGroupAndSort() {
        let math = tag(id: "m", name: "MATH101")
        let hist = tag(id: "h", name: "HIST200")
        let t1 = task(id: "a", title: "Problem set")
        let t2 = task(id: "b", title: "Essay")
        let t3 = task(id: "c", title: "Untagged chore")
        let sections = TagGrouping.sections(
            tasks: [t1, t2, t3],
            tagsByTaskId: [
                "a": [math],
                "b": [hist],
                "c": []
            ]
        )
        XCTAssertEqual(sections.map(\.title), ["HIST200", "MATH101", "Untagged"])
        XCTAssertEqual(sections[0].tasks.map(\.id), ["b"])
        XCTAssertEqual(sections[2].tasks.map(\.id), ["c"])
    }

    private func tag(id: String, name: String) -> TagRecord {
        let now = Date()
        return TagRecord(
            id: id,
            name: name,
            color: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
    }

    private func task(id: String, title: String) -> TaskRecord {
        let now = Date()
        return TaskRecord(
            id: id,
            listId: "list",
            title: title,
            notes: nil,
            isCompleted: false,
            completedAt: nil,
            dueDate: nil,
            hasDueTime: false,
            dueHour: nil,
            dueMinute: nil,
            priority: Priority.none.rawValue,
            sortOrder: 0,
            recurrenceJson: nil,
            reminderOffsetsJson: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
    }
}
