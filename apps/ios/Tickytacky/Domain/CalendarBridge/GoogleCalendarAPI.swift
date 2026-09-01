import Foundation

/// Thin REST client for Google Calendar API v3.
actor GoogleCalendarAPI {
    private let session: URLSession
    private let baseURL = URL(string: "https://www.googleapis.com/calendar/v3")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Calendars

    func listCalendars() async throws -> [GCalCalendar] {
        let url = baseURL.appending(path: "users/me/calendarList")
        let data = try await get(url)
        return try JSONDecoder.google.decode(GCalCalendarList.self, from: data).items ?? []
    }

    func insertCalendar(summary: String) async throws -> GCalCalendar {
        let url = baseURL.appending(path: "calendars")
        let body = GCalCalendarInsert(summary: summary)
        let data = try await post(url, body: body)
        return try JSONDecoder.google.decode(GCalCalendar.self, from: data)
    }

    // MARK: - Events

    struct EventListResult: Sendable {
        var events: [GCalEvent]
        var nextSyncToken: String?
        var nextPageToken: String?
    }

    func listEvents(
        calendarId: String,
        timeMin: Date? = nil,
        timeMax: Date? = nil,
        syncToken: String? = nil,
        pageToken: String? = nil
    ) async throws -> EventListResult {
        var comps = URLComponents(
            url: baseURL.appending(path: "calendars/\(calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId)/events"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "showDeleted", value: syncToken != nil ? "true" : "false"),
            URLQueryItem(name: "maxResults", value: "250"),
        ]
        if let syncToken {
            items.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let timeMin {
                items.append(URLQueryItem(name: "timeMin", value: formatter.string(from: timeMin)))
            }
            if let timeMax {
                items.append(URLQueryItem(name: "timeMax", value: formatter.string(from: timeMax)))
            }
        }
        if let pageToken {
            items.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        comps.queryItems = items
        guard let url = comps.url else { throw GoogleCalendarAPIError.badURL }

        do {
            let data = try await get(url)
            let decoded = try JSONDecoder.google.decode(GCalEventList.self, from: data)
            return EventListResult(
                events: decoded.items ?? [],
                nextSyncToken: decoded.nextSyncToken,
                nextPageToken: decoded.nextPageToken
            )
        } catch GoogleCalendarAPIError.httpStatus(410, _) {
            // Sync token expired — caller should clear and full-sync.
            throw GoogleCalendarAPIError.syncTokenExpired
        }
    }

    func insertEvent(calendarId: String, event: GCalEventWrite) async throws -> GCalEvent {
        let url = baseURL.appending(path: "calendars/\(encoded(calendarId))/events")
        let data = try await post(url, body: event)
        return try JSONDecoder.google.decode(GCalEvent.self, from: data)
    }

    func patchEvent(calendarId: String, eventId: String, event: GCalEventWrite) async throws -> GCalEvent {
        let url = baseURL.appending(path: "calendars/\(encoded(calendarId))/events/\(encoded(eventId))")
        let data = try await patch(url, body: event)
        return try JSONDecoder.google.decode(GCalEvent.self, from: data)
    }

    func deleteEvent(calendarId: String, eventId: String) async throws {
        let url = baseURL.appending(path: "calendars/\(encoded(calendarId))/events/\(encoded(eventId))")
        _ = try await request(url, method: "DELETE", bodyData: nil)
    }

    // MARK: - HTTP

    private func get(_ url: URL) async throws -> Data {
        try await request(url, method: "GET", bodyData: nil)
    }

    private func post<T: Encodable>(_ url: URL, body: T) async throws -> Data {
        let data = try JSONEncoder.google.encode(body)
        return try await request(url, method: "POST", bodyData: data)
    }

    private func patch<T: Encodable>(_ url: URL, body: T) async throws -> Data {
        let data = try JSONEncoder.google.encode(body)
        return try await request(url, method: "PATCH", bodyData: data)
    }

    private func request(_ url: URL, method: String, bodyData: Data?) async throws -> Data {
        let token = try await GoogleCalendarOAuth.shared.validAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GoogleCalendarAPIError.httpStatus(http.statusCode, body)
        }
        return data
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

enum GoogleCalendarAPIError: LocalizedError {
    case badURL
    case syncTokenExpired
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .badURL: "Invalid Google Calendar URL."
        case .syncTokenExpired: "Google sync token expired; full sync required."
        case .httpStatus(let code, let body):
            "Google Calendar API error (\(code)): \(body)"
        }
    }
}

// MARK: - DTOs

struct GCalCalendarList: Decodable, Sendable {
    var items: [GCalCalendar]?
}

struct GCalCalendar: Codable, Sendable {
    var id: String?
    var summary: String?
}

struct GCalCalendarInsert: Encodable, Sendable {
    var summary: String
}

struct GCalEventList: Decodable, Sendable {
    var items: [GCalEvent]?
    var nextPageToken: String?
    var nextSyncToken: String?
}

struct GCalEvent: Decodable, Sendable {
    var id: String?
    var status: String?
    var summary: String?
    var description: String?
    var start: GCalDateTime?
    var end: GCalDateTime?
    var updated: String?
    var extendedProperties: GCalExtendedProperties?
    var htmlLink: String?

    var occurrenceId: String? {
        extendedProperties?.privateProps?["tickytackyOccurrenceId"]
    }

    var updatedDate: Date? {
        guard let updated else { return nil }
        return Self.parseGoogleDate(updated)
    }

    private static func parseGoogleDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }
}

struct GCalEventWrite: Encodable, Sendable {
    var summary: String
    var description: String?
    var start: GCalDateTime
    var end: GCalDateTime
    var extendedProperties: GCalExtendedProperties?
}

struct GCalDateTime: Codable, Sendable {
    var dateTime: String?
    var timeZone: String?

    init(date: Date, timeZone: TimeZone = .current) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        self.dateTime = formatter.string(from: date)
        self.timeZone = timeZone.identifier
    }

    var date: Date? {
        guard let dateTime else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: dateTime) { return date }
        return ISO8601DateFormatter().date(from: dateTime)
    }
}

struct GCalExtendedProperties: Codable, Sendable {
    var privateProps: [String: String]?

    enum CodingKeys: String, CodingKey {
        case privateProps = "private"
    }
}

private extension JSONEncoder {
    static let google: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()
}

private extension JSONDecoder {
    static let google: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
