import SwiftUI

struct TagDetailView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    let tagId: String

    @State private var tag: TagRecord?
    @State private var tasks: [TaskRecord] = []
    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var selectedTaskIds: Set<String> = []

    private let theme = Theme.current

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            content
        }
        .navigationTitle(tag?.name ?? "Tag")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Rename") { showRename = true }
                    Button("Delete Tag", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Tag options")
                .disabled(tag == nil)
            }
        }
        .sheet(isPresented: $showRename) {
            if let tag {
                TagEditorSheet(mode: .rename(tag)) { _ in reload() }
            }
        }
        .confirmationDialog(
            "Delete this tag? Tasks keep their other tags.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteTag() }
            Button("Cancel", role: .cancel) {}
        }
        .task { reload() }
        .onAppear { reload() }
        .onChange(of: showRename) { _, open in
            if !open { reload() }
        }
        .onTaskListDeleteCommand(selection: selectedTaskIds) { ids in
            softDeleteTasks(ids)
        }
    }

    @ViewBuilder
    private var content: some View {
        if tag == nil {
            EmptyStateView(
                title: "Tag not found",
                message: "This tag may have been deleted."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if tasks.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "No tasks with this tag",
                    message: "Attach “\(tag?.name ?? "this tag")” from a task’s editor."
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
        tag = try? database.tags.fetch(id: tagId)
        tasks = (try? database.tags.fetchTasks(tagId: tagId)) ?? []
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

    private func deleteTag() {
        do {
            try database.tags.softDelete(id: tagId)
            dismiss()
        } catch {
            // Keep on screen if delete fails.
        }
    }
}
