import SwiftUI

/// One calendar day on Upcoming: schedule blocks (optional) + due tasks.
private struct UpcomingDayGroup: Identifiable {
    var day: Date
    var occurrences: [ScheduleOccurrence]
    var tasks: [TaskRecord]

    var id: Date { day }

    var isEmpty: Bool { occurrences.isEmpty && tasks.isEmpty }
}

struct UpcomingView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.calendar) private var calendar
    private let theme = Theme.current

    var embedsNavigationStack: Bool = true

    @State private var groups: [UpcomingDayGroup] = []
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
        ZStack {
            theme.canvas.ignoresSafeArea()
            content
        }
        .navigationTitle("Upcoming")
        .sheet(item: $selectedOccurrence) { occurrence in
            OccurrenceActionsSheet(occurrence: occurrence) { reload() }
        }
        .task { reload() }
        .onAppear { reload() }
        .onTaskListDeleteCommand(selection: selectedTaskIds) { ids in
            softDeleteTasks(ids)
        }
    }

    @ViewBuilder
    private var content: some View {
        if groups.isEmpty {
            EmptyStateView(
                title: "No upcoming items",
                message: "Due dates and schedule blocks for the next week will show here."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List(selection: $selectedTaskIds) {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.occurrences) { occurrence in
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
                        ForEach(group.tasks) { task in
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
                        .onDelete { softDeleteTasks(in: group, at: $0) }
                    } header: {
                        Text(dayTitle(group.day))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(theme.inkMuted)
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel(dayTitle(group.day))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { reload() }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    private func reload() {
        let taskGroups = (try? database.tasks.fetchUpcoming(days: 7)) ?? []
        var tasksByDay: [Date: [TaskRecord]] = [:]
        for group in taskGroups {
            let day = calendar.startOfDay(for: group.day)
            tasksByDay[day] = group.tasks
        }

        let tomorrow = calendar.startOfDay(for: DueDate.dayOffset(1))
        guard let endExclusive = calendar.date(byAdding: .day, value: 7, to: tomorrow) else {
            groups = []
            return
        }

        var occByDay: [Date: [ScheduleOccurrence]] = [:]
        var day = tomorrow
        while day < endExclusive {
            let occ = (try? database.schedules.occurrences(forDay: day, calendar: calendar)) ?? []
            if !occ.isEmpty {
                occByDay[day] = occ
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        var result: [UpcomingDayGroup] = []
        day = tomorrow
        while day < endExclusive {
            let tasks = tasksByDay[day] ?? []
            let occurrences = occByDay[day] ?? []
            if !tasks.isEmpty || !occurrences.isEmpty {
                result.append(UpcomingDayGroup(day: day, occurrences: occurrences, tasks: tasks))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        groups = result
    }

    private func toggle(_ task: TaskRecord) {
        _ = try? database.tasks.setCompleted(id: task.id, completed: !task.isCompleted)
        reload()
    }

    private func softDeleteTasks(in group: UpcomingDayGroup, at offsets: IndexSet) {
        for index in offsets {
            let id = group.tasks[index].id
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        reload()
    }

    private func softDeleteTasks(_ ids: Set<String>) {
        let taskIds = Set(groups.flatMap(\.tasks).map(\.id))
        for id in ids where taskIds.contains(id) {
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        reload()
    }
}
