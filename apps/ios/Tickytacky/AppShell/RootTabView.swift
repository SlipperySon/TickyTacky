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

    var body: some View {
        Group {
            if sizeClass == .compact {
                phoneTabs
            } else {
                regularSplit
            }
        }
        .tint(theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .tickytackyOpenReminderDeepLink)) { note in
            guard let link = note.object as? ReminderDeepLink else { return }
            handleDeepLink(link)
        }
        .sheet(item: $deepLinkTask) { payload in
            NavigationStack {
                TaskDetailView(taskId: payload.id)
            }
        }
        .sheet(item: $deepLinkOccurrence) { occurrence in
            OccurrenceActionsSheet(occurrence: occurrence)
        }
    }

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(0)
            UpcomingView()
                .tabItem { Label("Upcoming", systemImage: "calendar") }
                .tag(1)
            BrowseView()
                .tabItem { Label("Browse", systemImage: "folder") }
                .tag(2)
            TimetableView()
                .tabItem { Label("Timetable", systemImage: "clock") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
    }

    private var regularSplit: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                Label("Today", systemImage: "sun.max")
                    .tag(SidebarItem.today)
                Label("Upcoming", systemImage: "calendar")
                    .tag(SidebarItem.upcoming)
                Label("Browse", systemImage: "folder")
                    .tag(SidebarItem.browse)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
                Label("Timetable", systemImage: "clock")
                    .tag(SidebarItem.timetable)
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
            }
            .navigationTitle("Tickytacky")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                switch sidebarSelection ?? .today {
                case .today:
                    TodayView(embedsNavigationStack: false)
                case .upcoming:
                    UpcomingView(embedsNavigationStack: false)
                case .browse:
                    BrowseView(embedsNavigationStack: false)
                case .search:
                    SearchView()
                case .timetable:
                    TimetableView(embedsNavigationStack: false)
                case .settings:
                    SettingsView(embedsNavigationStack: false)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(theme.canvas)
    }

    private func handleDeepLink(_ link: ReminderDeepLink) {
        switch link {
        case .task(let id):
            selectedTab = 0
            sidebarSelection = .today
            deepLinkTask = DeepLinkTask(id: id)
        case .occurrence(let blockId, let originalStart):
            selectedTab = 3
            sidebarSelection = .timetable
            deepLinkOccurrence = resolveOccurrence(blockId: blockId, originalStart: originalStart)
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
    case today, upcoming, browse, search, timetable, settings
}

private struct DeepLinkTask: Identifiable {
    let id: String
}
