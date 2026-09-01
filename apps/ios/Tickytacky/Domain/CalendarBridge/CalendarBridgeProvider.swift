import Foundation

/// Shared surface for Apple / Google calendar bridges.
@MainActor
protocol CalendarBridgeProvider: AnyObject {
    /// Stable provider id, e.g. `"apple"` / `"google"`.
    var providerID: String { get }

    /// UserDefaults-backed enable flag.
    var isEnabled: Bool { get set }

    /// When true, pull external title/time edits into Tickytacky.
    var isTwoWayEnabled: Bool { get set }

    /// Push timetable occurrences to the external calendar.
    func publishTimetable() async throws

    /// Pull external edits back into Tickytacky (two-way).
    func pullChanges() async throws

    /// Remove Tickytacky-tagged events when the user disables the bridge.
    func clearPublished() async throws
}

enum CalendarBridgeProviderError: LocalizedError {
    case notConfigured
    case notAuthorized
    case missingClientID
    case dualWriteNotRecommended

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Calendar bridge is not configured."
        case .notAuthorized:
            "Calendar access is not authorized."
        case .missingClientID:
            "Add GOOGLE_CALENDAR_CLIENT_ID to Secrets.xcconfig."
        case .dualWriteNotRecommended:
            "Publishing to both Apple and Google can create duplicates in Calendar.app."
        }
    }
}
