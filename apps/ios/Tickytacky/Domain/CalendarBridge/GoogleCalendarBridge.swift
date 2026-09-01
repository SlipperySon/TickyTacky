import Foundation

/// Google Calendar bridge conforming to `CalendarBridgeProvider` — thin wrapper over
/// `GoogleCalendarPublisher`.
@MainActor
final class GoogleCalendarBridge: CalendarBridgeProvider {
    static let shared = GoogleCalendarBridge()

    static let enabledKey = CalendarBridgeDefaultsKey.googleEnabled

    let providerID = GoogleCalendarPublisher.providerID

    var isEnabled: Bool {
        get { GoogleCalendarPublisher.shared.isEnabled }
        set { GoogleCalendarPublisher.shared.isEnabled = newValue }
    }

    var isTwoWayEnabled: Bool {
        get { GoogleCalendarPublisher.shared.isTwoWayEnabled }
        set { GoogleCalendarPublisher.shared.isTwoWayEnabled = newValue }
    }

    private init() {}

    func publishTimetable() async throws {
        await GoogleCalendarPublisher.shared.publish()
    }

    func pullChanges() async throws {
        await GoogleCalendarPublisher.shared.pull()
    }

    func clearPublished() async throws {
        await GoogleCalendarPublisher.shared.clearPublishedEvents()
    }
}
