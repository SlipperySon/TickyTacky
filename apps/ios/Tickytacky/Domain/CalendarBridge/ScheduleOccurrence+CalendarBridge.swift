import Foundation

extension ScheduleOccurrence {
    /// Deep link used on EventKit / Google events: `tickytacky://schedule?id=<occurrenceId>`.
    var calendarBridgeURL: URL? {
        Self.calendarBridgeURL(occurrenceId: id)
    }

    static func calendarBridgeURL(occurrenceId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "tickytacky"
        components.host = "schedule"
        components.queryItems = [URLQueryItem(name: "id", value: occurrenceId)]
        return components.url
    }

    /// Parses `tickytacky://schedule?id=` into an occurrence id.
    static func occurrenceId(fromCalendarBridgeURL url: URL) -> String? {
        guard url.scheme == "tickytacky",
              url.host == "schedule",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let id = items.first(where: { $0.name == "id" })?.value,
              !id.isEmpty
        else { return nil }
        return id
    }

    /// Splits `blockID|ISO8601` into parts.
    static func parseID(_ id: String) -> (blockID: String, originalStart: Date)? {
        guard let separator = id.firstIndex(of: "|") else { return nil }
        let blockID = String(id[..<separator])
        let stamp = String(id[id.index(after: separator)...])
        guard !blockID.isEmpty,
              let originalStart = ISO8601DateFormatter().date(from: stamp)
        else { return nil }
        return (blockID, originalStart)
    }
}
