import SwiftUI

struct ListDetailView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    let listId: String

    @State private var list: TaskListRecord?
    @State private var tasks: [TaskRecord] = []
    @State private var showQuickAdd = false
    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var selectedTaskIds: Set<String> = []

    private let theme = Theme.current

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.canvas.ignoresSafeArea()
            content
            QuickAddButton { showQuickAdd = true }
                .padding(20)
        }
        .navigationTitle(list?.name ?? "List")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Rename") { showRename = true }
                    if list?.isInbox != true {
                        Button("Delete List", role: .destructive) { showDeleteConfirm = true }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("List options")
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(defaultListId: listId) { reload() }
        }
        .sheet(isPresented: $showRename) {
            if let list {
                ListEditorSheet(mode: .rename(list)) { reload() }
            }
        }
        .confirmationDialog(
            "Delete this list? Open tasks move to Inbox.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteList() }
            Button("Cancel", role: .cancel) {}
        }
        .task { reload() }
        .onAppear { reload() }
        .onChange(of: showQuickAdd) { _, open in
            if !open { reload() }
        }
        .onChange(of: showRename) { _, open in
            if !open { reload() }
        }
        .onTaskListDeleteCommand(selection: selectedTaskIds) { ids in
            softDeleteTasks(ids)
        }
    }

    @ViewBuilder
    private var content: some View {
        if list == nil {
            EmptyStateView(
                title: "List not found",
                message: "This list may have been deleted."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if tasks.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "No tasks here",
                    message: "Tap + to add something to \(list?.name ?? "this list")."
                )
                .padding(20)
            }
        } else {
            List(selection: $selectedTaskIds) {
                ForEach(tasks) { task in
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
            .refreshable { reload() }
        }
    }

    private func reload() {
        list = try? database.lists.fetch(id: listId)
        tasks = (try? database.tasks.fetchByList(listId: listId)) ?? []
    }

    private func toggle(_ task: TaskRecord) {
        _ = try? database.tasks.setCompleted(id: task.id, completed: !task.isCompleted)
        reload()
    }

    private func softDeleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            try? database.tasks.softDelete(id: tasks[index].id)
        }
        selectedTaskIds = []
        reload()
    }

    private func softDeleteTasks(_ ids: Set<String>) {
        for id in ids {
            try? database.tasks.softDelete(id: id)
        }
        selectedTaskIds = []
        reload()
    }

    private func deleteList() {
        do {
            try database.lists.delete(id: listId)
            dismiss()
        } catch {
            // Keep list on screen if delete fails (e.g. Inbox).
        }
    }
}
