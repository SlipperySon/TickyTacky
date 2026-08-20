import SwiftUI

struct TodayView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.calendar) private var calendar
    private let theme = Theme.current

    /// When false, parent (e.g. iPad/Mac split detail) already provides NavigationStack.
    var embedsNavigationStack: Bool = true

    @State private var snapshot = TodaySnapshot(overdue: [], schedule: [], dueToday: [])
    @State private var inboxId: String?
    @State private var showQuickAdd = false
    @State private var selectedOccurrence: ScheduleOccurrence?
    @State private var selectedTaskIds: Set<String> = []

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
        ZStack(alignment: .bottomTrailing) {
            theme.canvas.ignoresSafeArea()
            HStack(spacing: 0) {
                theme.canvasRuled
                    .frame(width: 14)
                    .ignoresSafeArea()
                content
            }
            QuickAddButton { showQuickAdd = true }
                .padding(20)
        }
        .navigationTitle("Today")
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(
                defaultListId: inboxId,
                defaultDueDate: DueDate.today()
            ) { reload() }
        }
        .sheet(item: $selectedOccurrence) { occurrence in
            OccurrenceActionsSheet(occurrence: occurrence) { reload() }
        }
        .task { reload() }
        .onAppear { reload() }
        .onChange(of: showQuickAdd) { _, open in
            if !open { reload() }
        }
        .onTaskListDeleteCommand(selection: selectedTaskIds) { ids in
            softDeleteTasks(ids)
        }
    }

    @ViewBuilder
    private var content: some View {
        if snapshot.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "Nothing for today",
                    message: "Overdue tasks, today’s schedule, and tasks due today will show here."
                )
                .padding(20)
            }
        } else {
            List(selection: $selectedTaskIds) {
                // Section order: Overdue → Schedule → Tasks due today (TodayAssembler).
                if !snapshot.overdue.isEmpty {
                    Section {
                        ForEach(snapshot.overdue) { task in
                            taskLink(task)
                        }
                        .onDelete { softDeleteOverdue(at: $0) }
                    } header: {
                        sectionHeader("Overdue", accessibilityHint: "\(snapshot.overdue.count) overdue tasks")
                    }
                }

                if !snapshot.schedule.isEmpty {
                    Section {
                        ForEach(snapshot.schedule) { occurrence in
                            Button {
                                selectedOccurrence = occurrence
                            } label: {
                                ScheduleOccurrenceRow(occurrence: occurrence)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(theme.canvas)
                            .listRowSeparatorTint(theme.rule)
                            .accessibilityHint("Opens occurrence actions")
                        }
                    } header: {
                        sectionHeader(
                            "Schedule",
                            accessibilityHint: "\(snapshot.schedule.count) schedule blocks today"
                        )
                    }
                }

                if !snapshot.dueToday.isEmpty {
                    Section {
                        ForEach(snapshot.dueToday) { task in
                            taskLink(task)
                        }
                        .onDelete { softDeleteDueToday(at: $0) }
                    } header: {
                        sectionHeader(
                            "Tasks due today",
                            accessibilityHint: "\(snapshot.dueToday.count) tasks due today"
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { reload() }
        }
    }

    private func taskLink(_ task: TaskRecord) -> some View {
        NavigationLink {
            TaskDetailView(taskId: task.id)
        } label: {
            TaskRow(task: task) {
                toggle(task)
            }
        }
        .listRowBackground(theme.canvas)
        .listRowSeparatorTint(theme.rule)
        .tag(task.id)
    }

    private func sectionHeader(_ title: String, accessibilityHint: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(theme.inkMuted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
            .accessibilityHint(accessibilityHint)
    }

    private func reload() {
        inboxId = try? database.fetchInbox()?.id
        let taskBundle = try? database.tasks.fetchToday()
        let occurrences = (try? database.schedules.occurrences(forDay: Date(), calendar: calendar)) ?? []
        snapshot = TodayAssembler.assemble(
            overdue: taskBundle?.overdue ?? [],
            dueToday: taskBundle?.dueToday ?? [],
            occurrences: occurrences
        )
    }

    private func toggle(_ task: TaskRecord) {
        _ = try? database.tasks.setCompleted(id: task.id, completed: !task.isCompleted)
        reload()
    }

    private func softDeleteOverdue(at offsets: IndexSet) {
        for index in offsets {
            let id = snapshot.overdue[index].id
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        reload()
    }

    private func softDeleteDueToday(at offsets: IndexSet) {
        for index in offsets {
            let id = snapshot.dueToday[index].id
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        reload()
    }

    private func softDeleteTasks(_ ids: Set<String>) {
        for id in ids where snapshot.overdue.contains(where: { $0.id == id })
            || snapshot.dueToday.contains(where: { $0.id == id })
        {
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        reload()
    }
}
