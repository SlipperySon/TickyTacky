import SwiftUI

/// Adaptive shell: tabs on iPhone; sidebar NavigationSplitView on iPad/Mac.
struct RootTabView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.horizontalSizeClass) private var sizeClass
    private let theme = Theme.current

    @State private var selectedTab = 0
    @State private var sidebarSelection: SidebarItem? = .today
    @State private var deepLinkTask: DeepLinkTask?
    @State private var deepLinkOccurrence: ScheduleOccurrence?
    @State private var showAddMenu = false
    @State private var showQuickAdd = false
    @State private var showScheduleEditor = false
    @State private var scheduleIdForCreate: String?

    var body: some View {
        Group {
            if sizeClass == .compact {
                phoneShell
            } else {
                regularSplit
            }
        }
        .tint(theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .tickytackyOpenReminderDeepLink)) { note in
            guard let link = note.object as? ReminderDeepLink else { return }
            handleDeepLink(link)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tickytackyOpenFocus)) { note in
            let taskId = note.object as? String
            FocusEngine.shared.prepare(taskId: taskId)
            selectedTab = 2
            sidebarSelection = .focus
        }
        .sheet(item: $deepLinkTask) { payload in
            NavigationStack {
                TaskDetailView(taskId: payload.id)
            }
        }
        .sheet(item: $deepLinkOccurrence) { occurrence in
            OccurrenceActionsSheet(occurrence: occurrence)
        }
        .confirmationDialog("Add", isPresented: $showAddMenu, titleVisibility: .hidden) {
            Button("Task") { showQuickAdd = true }
            Button("Schedule block") { prepareScheduleEditor() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(
                defaultListId: try? database.fetchInbox()?.id,
                defaultDueDate: DueDate.today()
            ) {
                NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
            }
        }
        .sheet(isPresented: $showScheduleEditor) {
            if let scheduleIdForCreate {
                ScheduleBlockEditorSheet(
                    mode: .create(
                        scheduleId: scheduleIdForCreate,
                        defaultWeekday: Calendar.current.component(.weekday, from: Date())
                    )
                ) {
                    NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
                }
            }
        }
    }

    private var phoneShell: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0:
                    BrowseView()
                case 1:
                    UpcomingView()
                case 2:
                    FocusView()
                default:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            CenterPlusTabBar(selectedTab: $selectedTab) {
                showAddMenu = true
            }
        }
        .background(theme.canvas.ignoresSafeArea())
    }

    private var regularSplit: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Label("Today", systemImage: "sun.max")
                    .tag(SidebarItem.today)
                Label("Calendar", systemImage: "calendar")
                    .tag(SidebarItem.calendar)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
                Label("Focus", systemImage: "timer")
                    .tag(SidebarItem.focus)
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
            }
            .navigationTitle("Tickytacky")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Task") { showQuickAdd = true }
                        Button("Schedule block") { prepareScheduleEditor() }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add task or schedule")
                }
            }
        } detail: {
            NavigationStack {
                switch sidebarSelection ?? .today {
                case .today:
                    BrowseView(embedsNavigationStack: false)
                case .calendar:
                    UpcomingView(embedsNavigationStack: false)
                case .search:
                    SearchView()
                case .focus:
                    FocusView(embedsNavigationStack: false)
                case .settings:
                    SettingsView(embedsNavigationStack: false)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(theme.canvas)
    }

    private func prepareScheduleEditor() {
        do {
            let schedule = try database.schedules.ensureDefaultSchedule()
            scheduleIdForCreate = schedule.id
            showScheduleEditor = true
        } catch {
            scheduleIdForCreate = nil
        }
    }

    private func handleDeepLink(_ link: ReminderDeepLink) {
        switch link {
        case .task(let id):
            selectedTab = 0
            sidebarSelection = .today
            NotificationCenter.default.post(name: .tickytackySelectBrowsePane, object: BrowsePane.today)
            deepLinkTask = DeepLinkTask(id: id)
        case .occurrence(let blockId, let originalStart):
            selectedTab = 1
            sidebarSelection = .calendar
            NotificationCenter.default.post(name: .tickytackySelectUpcomingPane, object: UpcomingPane.week)
            deepLinkOccurrence = resolveOccurrence(blockId: blockId, originalStart: originalStart)
        case .focus:
            selectedTab = 2
            sidebarSelection = .focus
            FocusEngine.shared.refreshFromClock()
        }
    }

    private func resolveOccurrence(blockId: String, originalStart: Date) -> ScheduleOccurrence? {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let from = calendar.startOfDay(for: originalStart)
        guard let to = calendar.date(byAdding: .day, value: 1, to: from),
              let schedule = try? database.schedules.fetchActiveSchedule(),
              let blocks = try? database.schedules.fetchBlocks(scheduleId: schedule.id)
        else { return nil }
        let exceptions = (try? database.schedules.fetchExceptions(
            blockIds: [blockId],
            from: from,
            to: to
        )) ?? []
        return OccurrenceGenerator.occurrences(
            blocks: blocks.map(ScheduleBlockInput.init(from:)),
            exceptions: exceptions.map(ScheduleExceptionInput.init(from:)),
            from: from,
            to: to,
            calendar: calendar
        ).first { $0.blockID == blockId && $0.originalStart == originalStart }
    }
}

private enum SidebarItem: Hashable {
    case today, calendar, search, focus, settings
}

private struct DeepLinkTask: Identifiable {
    let id: String
}

extension Notification.Name {
    static let tickytackyContentDidChange = Notification.Name("tickytackyContentDidChange")
}
