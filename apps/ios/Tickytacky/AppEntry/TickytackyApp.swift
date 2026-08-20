import SwiftUI

@main
struct TickytackyApp: App {
    private let database = AppDatabase.shared

    init() {
        ReminderScheduler.shared.configure()
        SyncEngine.shared.configure(database: database)
        #if DEBUG
        RecurrenceEngine.runSelfChecks()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appDatabase, database)
                .preferredColorScheme(nil)
                .onOpenURL { url in
                    if let link = ReminderDeepLink.parse(url: url) {
                        NotificationCenter.default.post(
                            name: .tickytackyOpenReminderDeepLink,
                            object: link
                        )
                    }
                }
                .task {
                    await ReminderScheduler.shared.refresh(database: database)
                    _ = AuthService.shared
                    SyncEngine.shared.syncIfPossible()
                }
                .background(ReminderLifecycleObserver(database: database))
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 480)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        #endif
    }
}

/// Refreshes reminders + best-effort sync on foreground.
private struct ReminderLifecycleObserver: View {
    @Environment(\.scenePhase) private var scenePhase
    let database: AppDatabase

    var body: some View {
        Color.clear
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await ReminderScheduler.shared.refresh(database: database)
                        SyncEngine.shared.syncIfPossible()
                    }
                }
            }
    }
}

private enum AppDatabaseKey: EnvironmentKey {
    static let defaultValue: AppDatabase = .shared
}

extension EnvironmentValues {
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}
