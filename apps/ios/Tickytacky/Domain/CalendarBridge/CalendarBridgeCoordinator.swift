import Foundation

/// Orchestrates Apple + Google calendar bridges: publish on content change / foreground,
/// schedule two-way pull, and surface dual-write warnings.
@MainActor
final class CalendarBridgeCoordinator {
    static let shared = CalendarBridgeCoordinator()

    private var didConfigure = false
    private var contentObserver: NSObjectProtocol?
    private var publishTask: Task<Void, Never>?
    private var pullTask: Task<Void, Never>?

    private init() {}

    var appleTwoWayEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: CalendarBridgeDefaultsKey.appleTwoWay) }
        set { UserDefaults.standard.set(newValue, forKey: CalendarBridgeDefaultsKey.appleTwoWay) }
    }

    var googleTwoWayEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: CalendarBridgeDefaultsKey.googleTwoWay) }
        set { UserDefaults.standard.set(newValue, forKey: CalendarBridgeDefaultsKey.googleTwoWay) }
    }

    /// True when both providers are enabled for write (duplicate risk in Calendar.app).
    var isDualWriteEnabled: Bool {
        EventKitCalendarPublisher.shared.isEnabled && GoogleCalendarPublisher.shared.isEnabled
    }

    var dualWriteWarningMessage: String {
        "Apple and Google publish are both on. If Calendar.app already shows your Google calendars, the same Tickytacky blocks can appear twice. Prefer one write target."
    }

    func configure() {
        guard !didConfigure else { return }
        didConfigure = true
        EventKitCalendarPublisher.shared.configure()
        GoogleCalendarPublisher.shared.configure()
        contentObserver = NotificationCenter.default.addObserver(
            forName: .tickytackyContentDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.schedulePublish()
            }
        }
    }

    func handleForeground() {
        configure()
        schedulePublish()
        schedulePull()
    }

    func schedulePublish(database: AppDatabase = .shared) {
        configure()
        publishTask?.cancel()
        publishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.publishEnabled(database: database)
        }
    }

    func schedulePull(database: AppDatabase = .shared) {
        configure()
        pullTask?.cancel()
        pullTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await self?.pullEnabled(database: database)
        }
    }

    func publishEnabled(database: AppDatabase = .shared) async {
        configure()
        if EventKitCalendarPublisher.shared.isEnabled {
            await EventKitCalendarPublisher.shared.publish(database: database)
        }
        if GoogleCalendarPublisher.shared.isEnabled {
            await GoogleCalendarPublisher.shared.publish(database: database)
        }
    }

    func pullEnabled(database: AppDatabase = .shared) async {
        configure()
        if EventKitCalendarPublisher.shared.isEnabled,
           EventKitCalendarPublisher.shared.isTwoWayEnabled {
            await EventKitCalendarPublisher.shared.pull(database: database)
        }
        if GoogleCalendarPublisher.shared.isEnabled,
           GoogleCalendarPublisher.shared.isTwoWayEnabled {
            await GoogleCalendarPublisher.shared.pull(database: database)
        }
    }
}
