import Foundation
import XCTest
@testable import Tickytacky

final class CalendarConflictResolverTests: XCTestCase {
    private let published = Date(timeIntervalSince1970: 1_700_000_000)
    private let beforePublish = Date(timeIntervalSince1970: 1_699_999_000)
    private let afterPublish = Date(timeIntervalSince1970: 1_700_000_500)

    private var local: CalendarConflictResolver.LocalOccurrence {
        .init(
            title: "Standup",
            start: Date(timeIntervalSince1970: 1_700_001_000),
            end: Date(timeIntervalSince1970: 1_700_001_800)
        )
    }

    func testMatchingEventsIgnored() {
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Standup",
            start: local.start,
            end: local.end,
            lastModified: afterPublish
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: published
        )
        XCTAssertEqual(action, .ignore)
    }

    func testNeverPublishedIgnoresExternalDiff() {
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Renamed",
            start: local.start,
            end: local.end,
            lastModified: afterPublish
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: nil
        )
        XCTAssertEqual(action, .ignore)
    }

    func testExternalOlderThanPublishIgnored() {
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Renamed",
            start: local.start,
            end: local.end,
            lastModified: beforePublish
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: published
        )
        XCTAssertEqual(action, .ignore)
    }

    func testExternalTitleAfterPublishApplies() {
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Renamed",
            start: local.start,
            end: local.end,
            lastModified: afterPublish
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: published
        )
        XCTAssertEqual(action, .applyTitle("Renamed"))
    }

    func testExternalRescheduleAfterPublishApplies() {
        let newStart = local.start.addingTimeInterval(600)
        let newEnd = local.end.addingTimeInterval(600)
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Standup",
            start: newStart,
            end: newEnd,
            lastModified: afterPublish
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: published
        )
        XCTAssertEqual(action, .applyReschedule(start: newStart, end: newEnd))
    }

    func testExternalTitleAndTimeApplyTogether() {
        let newStart = local.start.addingTimeInterval(600)
        let newEnd = local.end.addingTimeInterval(600)
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Renamed",
            start: newStart,
            end: newEnd,
            lastModified: afterPublish
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: published
        )
        XCTAssertEqual(
            action,
            .applyTitleAndReschedule(title: "Renamed", start: newStart, end: newEnd)
        )
    }

    func testMissingLastModifiedStillAppliesWhenPublished() {
        // Without lastModified we cannot prove echo; treat as external edit after publish.
        let external = CalendarConflictResolver.ExternalEvent(
            title: "Renamed",
            start: local.start,
            end: local.end,
            lastModified: nil
        )
        let action = CalendarConflictResolver.resolve(
            local: local,
            external: external,
            lastPublishedAt: published
        )
        XCTAssertEqual(action, .applyTitle("Renamed"))
    }

    func testOccurrenceDeepLinkRoundTrip() {
        let blockID = "block-abc"
        let originalStart = Date(timeIntervalSince1970: 1_700_100_000)
        let occurrenceId = ScheduleOccurrence.makeID(blockID: blockID, originalStart: originalStart)

        let url = ScheduleOccurrence.calendarBridgeURL(occurrenceId: occurrenceId)
        XCTAssertNotNil(url)
        XCTAssertEqual(ScheduleOccurrence.occurrenceId(fromCalendarBridgeURL: url!), occurrenceId)

        let parsed = ScheduleOccurrence.parseID(occurrenceId)
        XCTAssertEqual(parsed?.blockID, blockID)
        XCTAssertEqual(
            parsed?.originalStart.timeIntervalSince1970 ?? -1,
            originalStart.timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testOccurrenceIdRejectsNonScheduleURLs() {
        let url = URL(string: "tickytacky://task/abc")!
        XCTAssertNil(ScheduleOccurrence.occurrenceId(fromCalendarBridgeURL: url))
        XCTAssertNil(ScheduleOccurrence.parseID("not-a-valid-id"))
    }
}
