import Foundation

/// Apple bridge conforming to `CalendarBridgeProvider` — thin wrapper over
/// `EventKitCalendarPublisher`.
@MainActor
final class AppleCalendarBridge: CalendarBridgeProvider {
    static let shared = AppleCalendarBridge()

    let providerID = EventKitCalendarPublisher.providerID

    var isEnabled: Bool {
        get { EventKitCalendarPublisher.shared.isEnabled }
        set { EventKitCalendarPublisher.shared.isEnabled = newValue }
    }

    var isTwoWayEnabled: Bool {
        get { EventKitCalendarPublisher.shared.isTwoWayEnabled }
        set { EventKitCalendarPublisher.shared.isTwoWayEnabled = newValue }
    }

    private init() {}

    func publishTimetable() async throws {
        await EventKitCalendarPublisher.shared.publish()
    }

    func pullChanges() async throws {
        await EventKitCalendarPublisher.shared.pull()
    }

    func clearPublished() async throws {
        await EventKitCalendarPublisher.shared.clearPublishedEvents()
    }
}
