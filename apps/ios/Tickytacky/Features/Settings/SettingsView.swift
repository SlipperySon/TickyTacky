import AuthenticationServices
import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase

    var embedsNavigationStack: Bool = true

    private let theme = Theme.current
    private let supabase = SupabaseClientConfig.shared

    @State private var auth = AuthService.shared
    @State private var sync = SyncEngine.shared
    @State private var notificationStatus: ReminderScheduler.AuthorizationStatus = .notDetermined

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { root }
            } else {
                root
            }
        }
    }

    private var root: some View {
        List {
            accountSection
            syncSection
            notificationsSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Settings")
        .task {
            await reloadNotificationStatus()
            sync.refreshDirtyCount()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await reloadNotificationStatus()
                    sync.syncIfPossible()
                    sync.refreshDirtyCount()
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if !supabase.isConfigured {
                Text("Add SUPABASE_URL and SUPABASE_ANON_KEY in Secrets.xcconfig to enable cloud sync.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
            } else if auth.isSignedIn {
                LabeledContent("Status") {
                    Text("Signed in")
                        .foregroundStyle(theme.inkMuted)
                }
                if let email = auth.userEmail, !email.isEmpty {
                    LabeledContent("Apple ID") {
                        Text(email)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }
                }
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                .disabled(auth.isLoading)
            } else {
                LabeledContent("Status") {
                    Text("Signed out")
                        .foregroundStyle(theme.inkMuted)
                }
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await auth.handleAppleAuthorization(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .disabled(auth.isLoading || !supabase.isConfigured)

                Text("Sign in is required to sync across devices. Local tasks, lists, and timetable work offline without an account.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
            }

            if let error = auth.lastError, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.danger)
            }
        } header: {
            Text("Account")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Cloud sync needs a Tickytacky account (Sign in with Apple). Everything still works on this device when signed out.")
                .foregroundStyle(theme.inkFaint)
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        Section {
            LabeledContent("Backend") {
                Text(supabase.isConfigured ? "Configured" : "Not configured")
                    .foregroundStyle(theme.inkMuted)
            }
            LabeledContent("Status") {
                Text(sync.statusMessage)
                    .foregroundStyle(theme.inkMuted)
            }
            if let last = sync.lastSyncAt {
                LabeledContent("Last sync") {
                    Text(last.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            LabeledContent("Pending") {
                Text("\(sync.pendingDirtyCount)")
                    .foregroundStyle(theme.inkMuted)
            }
            Button {
                Task { await sync.syncNow() }
            } label: {
                if sync.isSyncing {
                    Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .tint(theme.accent)
            .disabled(sync.isSyncing || !supabase.isConfigured || !auth.isSignedIn)

            if let error = sync.lastError, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(theme.danger)
            }
        } header: {
            Text("Sync")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Changes save locally first, then push when you are signed in and online. Conflicts use last-write-wins per record.")
                .foregroundStyle(theme.inkFaint)
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            LabeledContent("Status") {
                Text(notificationStatus.settingsLabel)
                    .foregroundStyle(theme.inkMuted)
            }
            switch notificationStatus {
            case .notDetermined:
                Button("Enable Reminders") {
                    Task {
                        _ = await ReminderScheduler.shared.requestAuthorization()
                        await reloadNotificationStatus()
                        await ReminderScheduler.shared.refresh()
                    }
                }
                .tint(theme.accent)
            case .denied:
                Button("Open System Settings") {
                    ReminderScheduler.shared.openSystemNotificationSettings()
                }
                .tint(theme.accent)
                Text("Notifications are off. Enable them in Settings to get due and timetable reminders.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
            case .authorized, .provisional, .ephemeral:
                Text("Reminders fire for task due times and timetable blocks you’ve configured.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
                Text("Reliable delivery needs a physical iPhone — Simulator scheduling APIs work, but timed fires are limited.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkFaint)
            }
        } header: {
            Text("Notifications")
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: "Tickytacky")
            LabeledContent(
                "Version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
            )
            LabeledContent("Theme", value: "Classic Notebook")
        } header: {
            Text("About")
                .accessibilityAddTraits(.isHeader)
        }
    }

    @MainActor
    private func reloadNotificationStatus() async {
        notificationStatus = await ReminderScheduler.shared.authorizationStatus()
    }
}
