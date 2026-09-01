import SwiftUI

struct SearchView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.theme) private var theme

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var results: [TaskRecord] = []
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedTaskIds: Set<String> = []

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            content
        }
        .navigationTitle("Search")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $query, prompt: "Title or notes")
        .onChange(of: query) { _, newValue in
            scheduleDebounce(newValue)
        }
        .onChange(of: debouncedQuery) { _, _ in
            runSearch()
        }
        .onAppear { runSearch() }
        .onDisappear { debounceTask?.cancel() }
        .onTaskListDeleteCommand(selection: selectedTaskIds) { ids in
            softDeleteTasks(ids)
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyStateView(
                title: "Search tasks",
                message: "Matches titles and notes. Results update as you type."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if results.isEmpty {
            EmptyStateView(
                title: "No matches",
                message: "Nothing found for “\(trimmed)”."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List(selection: $selectedTaskIds) {
                ForEach(results) { task in
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
                .onDelete(perform: softDeleteAtOffsets)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func scheduleDebounce(_ value: String) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            debouncedQuery = value
        }
    }

    private func runSearch() {
        results = (try? database.search.searchTasks(query: debouncedQuery)) ?? []
    }

    private func toggle(_ task: TaskRecord) {
        _ = try? database.tasks.setCompleted(id: task.id, completed: !task.isCompleted)
        runSearch()
    }

    private func softDeleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            try? database.tasks.softDelete(id: results[index].id)
        }
        selectedTaskIds = []
        runSearch()
    }

    private func softDeleteTasks(_ ids: Set<String>) {
        for id in ids {
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        runSearch()
    }
}
