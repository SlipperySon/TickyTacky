import Foundation

/// External calendar event ↔ Tickytacky occurrence mapping.
struct CalendarExternalIDMapping: Equatable, Sendable, Codable {
    /// `"apple"` or `"google"` (matches `CalendarBridgeProvider.providerID`).
    var provider: String

    /// Tickytacky `ScheduleOccurrence.id`.
    var occurrenceId: String

    /// EventKit `eventIdentifier` or Google Calendar `event.id`.
    var externalEventId: String

    /// Optional: EventKit calendar identifier or Google `calendarId`.
    var externalCalendarId: String?

    /// Last successful publish from Tickytacky (echo suppression / conflict).
    var lastPublishedAt: Date?
}

// MARK: - Key constants

enum CalendarBridgeDefaultsKey {
    static let appleEnabled = "calendarBridge.apple.enabled"
    static let googleEnabled = "calendarBridge.google.enabled"
    static let appleTwoWay = "calendarBridge.apple.twoWay"
    static let googleTwoWay = "calendarBridge.google.twoWay"
    static let appleCalendarIdentifier = "calendarBridge.apple.calendarIdentifier"
    static let googleCalendarId = "calendarBridge.google.calendarId"
    static let googleSyncToken = "calendarBridge.google.syncToken"
    static let eventMappings = "calendarBridge.eventMappings"
    /// Legacy optional JSON map; prefer `eventMappings`.
    static let googleEventMap = "calendarBridge.google.eventMap"
}
