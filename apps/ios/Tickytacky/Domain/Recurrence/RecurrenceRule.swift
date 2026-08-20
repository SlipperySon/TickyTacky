import Foundation

/// How often a recurring task repeats.
enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    /// Singular unit label for “Every N …” copy.
    var intervalUnit: String {
        switch self {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }
    }

    var intervalUnitPlural: String {
        intervalUnit + "s"
    }
}

/// Structured recurrence rule stored as JSON in `tasks.recurrence_json`.
///
/// MVP fields only. `byWeekdays` is reserved for custom weekly (P1); the engine
/// ignores it in MVP and treats weekly as “same weekday every N weeks”.
struct RecurrenceRule: Codable, Equatable, Sendable {
    var frequency: RecurrenceFrequency
    /// Every N periods; always ≥ 1.
    var interval: Int
    /// Series start (date-only semantics; stored as `yyyy-MM-dd` in JSON).
    var startDate: Date
    /// Optional weekday filter for weekly (Calendar weekday: 1=Sunday … 7=Saturday). Stubbed.
    var byWeekdays: [Int]?

    init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        startDate: Date,
        byWeekdays: [Int]? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.startDate = startDate
        self.byWeekdays = byWeekdays
    }

    enum CodingKeys: String, CodingKey {
        case frequency, interval, startDate, byWeekdays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try container.decode(RecurrenceFrequency.self, forKey: .frequency)
        interval = max(1, try container.decode(Int.self, forKey: .interval))
        let startString = try container.decode(String.self, forKey: .startDate)
        guard let parsed = RecurrenceRuleCoding.parseDay(startString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .startDate,
                in: container,
                debugDescription: "Expected yyyy-MM-dd, got \(startString)"
            )
        }
        startDate = parsed
        byWeekdays = try container.decodeIfPresent([Int].self, forKey: .byWeekdays)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(max(1, interval), forKey: .interval)
        try container.encode(RecurrenceRuleCoding.formatDay(startDate), forKey: .startDate)
        try container.encodeIfPresent(byWeekdays, forKey: .byWeekdays)
    }

    /// Encode for `tasks.recurrence_json`, or `nil` if encoding fails.
    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func from(jsonString: String?) -> RecurrenceRule? {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
    }
}

enum RecurrenceRuleCoding {
    /// Date-only encoding matches `DueDate` / `SyncMapper` (local calendar, not UTC).
    static func formatDay(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func parseDay(_ string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
        else { return nil }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) }
    }
}
