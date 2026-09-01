import AuthenticationServices
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase

    var embedsNavigationStack: Bool = true

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var themeStore = ThemeStore.shared
    private let supabase = SupabaseClientConfig.shared

    @State private var auth = AuthService.shared
    @State private var sync = SyncEngine.shared
    @State private var notificationStatus: ReminderScheduler.AuthorizationStatus = .notDetermined
    @State private var calendarBridgeEnabled = EventKitCalendarPublisher.shared.isEnabled
    @State private var calendarAuthStatus = EventKitCalendarPublisher.shared.authorizationStatus()
    @State private var appleTwoWayEnabled = EventKitCalendarPublisher.shared.isTwoWayEnabled
    @State private var googleBridgeEnabled = GoogleCalendarPublisher.shared.isEnabled
    @State private var googleTwoWayEnabled = GoogleCalendarPublisher.shared.isTwoWayEnabled
    @State private var googleConfigured = GoogleCalendarPublisher.shared.isConfigured
    @State private var googleSignedIn = GoogleCalendarPublisher.shared.isSignedIn
    @State private var googleStatusMessage: String?
    @State private var dualWriteEnabled = CalendarBridgeCoordinator.shared.isDualWriteEnabled
    @State private var syncKeyDraft = ""
    @State private var showSyncKeyCopied = false
    #if DEBUG
    @State private var sampleSeedMessage: String?
    #endif

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
            appearanceSection
            accountSection
            syncSection
            calendarBridgeSection
            focusSection
            notificationsSection
            #if DEBUG
            debugSampleSection
            #endif
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Settings")
        .task {
            await reloadNotificationStatus()
            reloadCalendarBridgeStatus()
            sync.refreshDirtyCount()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await reloadNotificationStatus()
                    reloadCalendarBridgeStatus()
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
                if let email = auth.userEmail, !email.isEmpty, !email.hasSuffix(".invalid") {
                    LabeledContent("Apple ID") {
                        Text(email)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }
                }
                if let key = auth.lastIssuedSyncKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync key (copy now — it is not shown again)")
                            .font(.footnote)
                            .foregroundStyle(theme.inkMuted)
                        Text(key)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Button(showSyncKeyCopied ? "Copied" : "Copy sync key") {
                            copyToPasteboard(key)
                            showSyncKeyCopied = true
                        }
                    }
                }
                Button("Create sync key for other devices") {
                    Task { await auth.issueSyncKey() }
                }
                .disabled(auth.isLoading)
                Button("Sign Out", role: .destructive) {
                    Task { await auth.signOut() }
                }
                .disabled(auth.isLoading)
            } else {
                LabeledContent("Status") {
                    Text("Signed out")
                        .foregroundStyle(theme.inkMuted)
                }
                Button("Create sync key") {
                    Task { await auth.issueSyncKey() }
                }
                .disabled(auth.isLoading)
                TextField("Paste sync key from iPhone", text: $syncKeyDraft)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                Button("Use this sync key") {
                    Task { await auth.redeemSyncKey(syncKeyDraft) }
                }
                .disabled(auth.isLoading || syncKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                SignInWithAppleButton(.signIn) { request in
                    auth.prepareAppleSignInRequest(request)
                } onCompletion: { result in
                    Task { await auth.handleAppleAuthorization(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .disabled(auth.isLoading || !supabase.isConfigured)

                Text("Create a sync key on this device, then paste it on Web, Android, or Windows. Local data still works without an account. Sign in with Apple is optional.")
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
        .notebookGroupedRowBackground()
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
        .notebookGroupedRowBackground()
    }

    @ViewBuilder
    private var calendarBridgeSection: some View {
        Section {
            Toggle("Apple Calendar", isOn: Binding(
                get: { calendarBridgeEnabled },
                set: { newValue in
                    calendarBridgeEnabled = newValue
                    Task {
                        if newValue {
                            await EventKitCalendarPublisher.shared.enableAndPublish()
                        } else {
                            EventKitCalendarPublisher.shared.isEnabled = false
                        }
                        reloadCalendarBridgeStatus()
                    }
                }
            ))
            .tint(theme.accent)

            LabeledContent("Access") {
                Text(calendarAuthStatus.settingsLabel)
                    .foregroundStyle(theme.inkMuted)
            }

            if calendarBridgeEnabled, calendarAuthStatus == .denied || calendarAuthStatus == .restricted {
                Text("Calendar access is off. Enable it in System Settings so Tickytacky can update the Tickytacky calendar.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
                Button("Open System Settings") {
                    ReminderScheduler.shared.openSystemNotificationSettings()
                }
                .tint(theme.accent)
            }

            if calendarBridgeEnabled {
                Toggle("Allow Calendar edits to update Tickytacky", isOn: Binding(
                    get: { appleTwoWayEnabled },
                    set: { newValue in
                        appleTwoWayEnabled = newValue
                        Task {
                            if newValue {
                                let ok = await EventKitCalendarPublisher.shared.enableTwoWayAndPull()
                                if !ok {
                                    appleTwoWayEnabled = false
                                    googleStatusMessage = "Full calendar access is required for two-way Apple sync."
                                }
                            } else {
                                EventKitCalendarPublisher.shared.isTwoWayEnabled = false
                            }
                            reloadCalendarBridgeStatus()
                        }
                    }
                ))
                .tint(theme.accent)
                .disabled(!calendarAuthStatus.isUsable)

                if appleTwoWayEnabled, calendarAuthStatus == .writeOnly {
                    Text("Two-way needs full calendar access (write-only is not enough). Re-enable access in System Settings.")
                        .font(.footnote)
                        .foregroundStyle(theme.inkMuted)
                }
            }

            if calendarBridgeEnabled, calendarAuthStatus.isUsable {
                Button("Publish Apple now") {
                    Task {
                        await EventKitCalendarPublisher.shared.publish()
                        reloadCalendarBridgeStatus()
                    }
                }
                .tint(theme.accent)
            }

            if !googleConfigured {
                Text("Add GOOGLE_CALENDAR_CLIENT_ID to Secrets.xcconfig")
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
            }

            Toggle("Google Calendar", isOn: Binding(
                get: { googleBridgeEnabled },
                set: { newValue in
                    googleBridgeEnabled = newValue
                    Task {
                        do {
                            googleStatusMessage = nil
                            if newValue {
                                try await GoogleCalendarPublisher.shared.enableAndPublish()
                            } else {
                                GoogleCalendarPublisher.shared.isEnabled = false
                            }
                        } catch {
                            googleBridgeEnabled = false
                            GoogleCalendarPublisher.shared.isEnabled = false
                            googleStatusMessage = error.localizedDescription
                        }
                        reloadCalendarBridgeStatus()
                    }
                }
            ))
            .tint(theme.accent)
            .disabled(!googleConfigured)

            if googleConfigured {
                LabeledContent("Google account") {
                    Text(googleSignedIn ? "Signed in" : "Signed out")
                        .foregroundStyle(theme.inkMuted)
                }

                if !googleSignedIn {
                    Button("Sign in with Google") {
                        Task {
                            do {
                                googleStatusMessage = nil
                                try await GoogleCalendarPublisher.shared.signIn()
                            } catch {
                                googleStatusMessage = error.localizedDescription
                            }
                            reloadCalendarBridgeStatus()
                        }
                    }
                    .tint(theme.accent)
                } else {
                    Button("Sign out of Google", role: .destructive) {
                        GoogleCalendarPublisher.shared.signOut()
                        reloadCalendarBridgeStatus()
                    }
                }
            }

            if googleBridgeEnabled, googleConfigured, googleSignedIn {
                Toggle("Allow Google Calendar edits to update Tickytacky", isOn: Binding(
                    get: { googleTwoWayEnabled },
                    set: { newValue in
                        googleTwoWayEnabled = newValue
                        Task {
                            do {
                                googleStatusMessage = nil
                                if newValue {
                                    _ = try await GoogleCalendarPublisher.shared.enableTwoWayAndPull()
                                } else {
                                    GoogleCalendarPublisher.shared.isTwoWayEnabled = false
                                }
                            } catch {
                                googleTwoWayEnabled = false
                                googleStatusMessage = error.localizedDescription
                            }
                            reloadCalendarBridgeStatus()
                        }
                    }
                ))
                .tint(theme.accent)

                Button("Publish Google now") {
                    Task {
                        await GoogleCalendarPublisher.shared.publish()
                        reloadCalendarBridgeStatus()
                    }
                }
                .tint(theme.accent)
            }

            if dualWriteEnabled {
                Text(CalendarBridgeCoordinator.shared.dualWriteWarningMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.danger)
            }

            if let googleStatusMessage, !googleStatusMessage.isEmpty {
                Text(googleStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.danger)
            }
        } header: {
            Text("Calendar bridge")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Timetable blocks publish into a dedicated Tickytacky calendar on Apple and/or Google. Prefer one write target if Calendar.app already mirrors Google — enabling both can create duplicates. Two-way applies external title/time edits only when they clearly land after Tickytacky’s last publish; Tickytacky still wins when ambiguous. External deletes never remove local blocks.")
                .foregroundStyle(theme.inkFaint)
        }
        .notebookGroupedRowBackground()
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            Picker("Dark", selection: $themeStore.darkThemeID) {
                ForEach(DarkThemeID.allCases) { id in
                    Text(id.displayName).tag(id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityLabel("Dark appearance")
        } header: {
            Text("Dark appearance")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text(themeStore.darkThemeID.footer)
                .foregroundStyle(theme.inkFaint)
        }
        .notebookGroupedRowBackground()
    }

    @ViewBuilder
    private var focusSection: some View {
        Section {
            Stepper(value: Binding(
                get: { FocusSettings.workMinutes },
                set: {
                    FocusSettings.workMinutes = $0
                    FocusEngine.shared.reloadDurationsFromSettings()
                }
            ), in: 1...90) {
                LabeledContent("Focus", value: "\(FocusSettings.workMinutes) min")
            }
            Stepper(value: Binding(
                get: { FocusSettings.shortBreakMinutes },
                set: {
                    FocusSettings.shortBreakMinutes = $0
                    FocusEngine.shared.reloadDurationsFromSettings()
                }
            ), in: 1...30) {
                LabeledContent("Short break", value: "\(FocusSettings.shortBreakMinutes) min")
            }
            Stepper(value: Binding(
                get: { FocusSettings.longBreakMinutes },
                set: {
                    FocusSettings.longBreakMinutes = $0
                    FocusEngine.shared.reloadDurationsFromSettings()
                }
            ), in: 1...60) {
                LabeledContent("Long break", value: "\(FocusSettings.longBreakMinutes) min")
            }
            Stepper(value: Binding(
                get: { FocusSettings.sessionsUntilLongBreak },
                set: { FocusSettings.sessionsUntilLongBreak = $0 }
            ), in: 2...8) {
                LabeledContent("Long break every", value: "\(FocusSettings.sessionsUntilLongBreak) focus")
            }
            Toggle("Auto-start break", isOn: Binding(
                get: { FocusSettings.autoStartBreak },
                set: { FocusSettings.autoStartBreak = $0 }
            ))
            .tint(theme.accent)
            Toggle("Auto-start next focus", isOn: Binding(
                get: { FocusSettings.autoStartWork },
                set: { FocusSettings.autoStartWork = $0 }
            ))
            .tint(theme.accent)
        } header: {
            Text("Focus")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Classic Pomodoro defaults: 25 / 5 / 15. Sessions stay on this device.")
                .foregroundStyle(theme.inkFaint)
        }
        .notebookGroupedRowBackground()
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
        .notebookGroupedRowBackground()
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: "Tickytacky")
            LabeledContent(
                "Version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
            )
            LabeledContent("Theme", value: aboutThemeName)
        } header: {
            Text("About")
                .accessibilityAddTraits(.isHeader)
        }
        .notebookGroupedRowBackground()
    }

    #if DEBUG
    private var debugSampleSection: some View {
        Section {
            Button("Insert sample data") {
                do {
                    sampleSeedMessage = try DebugSampleSeeder.seed(database: .shared)
                } catch {
                    sampleSeedMessage = error.localizedDescription
                }
            }
            .tint(theme.accent)
            if let sampleSeedMessage {
                Text(sampleSeedMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.inkMuted)
            }
        } header: {
            Text("Debug")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Adds Life + Groceries, tags (Work, MATH101…), overdue & upcoming tasks, timetable, and a focus session. Group by tag is turned on. Re-running adds another task batch; schedule blocks only seed when empty.")
                .foregroundStyle(theme.inkFaint)
        }
        .notebookGroupedRowBackground()
    }
    #endif

    private var aboutThemeName: String {
        if colorScheme == .dark {
            themeStore.darkThemeID.displayName
        } else {
            "Classic Notebook"
        }
    }

    @MainActor
    private func reloadNotificationStatus() async {
        notificationStatus = await ReminderScheduler.shared.authorizationStatus()
    }

    private func reloadCalendarBridgeStatus() {
        calendarBridgeEnabled = EventKitCalendarPublisher.shared.isEnabled
        calendarAuthStatus = EventKitCalendarPublisher.shared.authorizationStatus()
        appleTwoWayEnabled = EventKitCalendarPublisher.shared.isTwoWayEnabled
        googleBridgeEnabled = GoogleCalendarPublisher.shared.isEnabled
        googleTwoWayEnabled = GoogleCalendarPublisher.shared.isTwoWayEnabled
        googleConfigured = GoogleCalendarPublisher.shared.isConfigured
        googleSignedIn = GoogleCalendarPublisher.shared.isSignedIn
        dualWriteEnabled = CalendarBridgeCoordinator.shared.isDualWriteEnabled
    }

    private func copyToPasteboard(_ value: String) {
        #if os(iOS)
        UIPasteboard.general.string = value
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}
