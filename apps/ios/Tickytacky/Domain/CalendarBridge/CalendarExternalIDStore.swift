import Foundation

/// UserDefaults JSON persistence for external calendar event ↔ occurrence mappings
/// plus Google calendar id / sync token helpers.
@MainActor
final class CalendarExternalIDStore {
    static let shared = CalendarExternalIDStore()

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Mappings

    func allMappings() -> [CalendarExternalIDMapping] {
        guard let data = defaults.data(forKey: CalendarBridgeDefaultsKey.eventMappings),
              let rows = try? decoder.decode([CalendarExternalIDMapping].self, from: data)
        else { return [] }
        return rows
    }

    func mappings(for provider: String) -> [CalendarExternalIDMapping] {
        allMappings().filter { $0.provider == provider }
    }

    func mapping(provider: String, occurrenceId: String) -> CalendarExternalIDMapping? {
        allMappings().first { $0.provider == provider && $0.occurrenceId == occurrenceId }
    }

    func upsert(_ mapping: CalendarExternalIDMapping) {
        var rows = allMappings()
        if let idx = rows.firstIndex(where: {
            $0.provider == mapping.provider && $0.occurrenceId == mapping.occurrenceId
        }) {
            rows[idx] = mapping
        } else {
            rows.append(mapping)
        }
        save(rows)
    }

    func recordPublish(
        provider: String,
        occurrenceId: String,
        externalEventId: String,
        externalCalendarId: String?,
        at date: Date = Date()
    ) {
        upsert(
            CalendarExternalIDMapping(
                provider: provider,
                occurrenceId: occurrenceId,
                externalEventId: externalEventId,
                externalCalendarId: externalCalendarId,
                lastPublishedAt: date
            )
        )
    }

    func remove(provider: String, occurrenceId: String) {
        save(allMappings().filter { !($0.provider == provider && $0.occurrenceId == occurrenceId) })
    }

    func removeAll(provider: String) {
        save(allMappings().filter { $0.provider != provider })
    }

    // MARK: - Apple calendar id

    var appleCalendarIdentifier: String? {
        get {
            let value = defaults.string(forKey: CalendarBridgeDefaultsKey.appleCalendarIdentifier)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: CalendarBridgeDefaultsKey.appleCalendarIdentifier)
            } else {
                defaults.removeObject(forKey: CalendarBridgeDefaultsKey.appleCalendarIdentifier)
            }
        }
    }

    // MARK: - Google calendar id / sync token

    var googleCalendarId: String? {
        get {
            let value = defaults.string(forKey: CalendarBridgeDefaultsKey.googleCalendarId)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: CalendarBridgeDefaultsKey.googleCalendarId)
            } else {
                defaults.removeObject(forKey: CalendarBridgeDefaultsKey.googleCalendarId)
            }
        }
    }

    var googleSyncToken: String? {
        get {
            let value = defaults.string(forKey: CalendarBridgeDefaultsKey.googleSyncToken)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: CalendarBridgeDefaultsKey.googleSyncToken)
            } else {
                defaults.removeObject(forKey: CalendarBridgeDefaultsKey.googleSyncToken)
            }
        }
    }

    // MARK: - Private

    private func save(_ rows: [CalendarExternalIDMapping]) {
        guard let data = try? encoder.encode(rows) else { return }
        defaults.set(data, forKey: CalendarBridgeDefaultsKey.eventMappings)
    }
}
