import SwiftUI

struct ListDetailView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    let listId: String

    @State private var list: TaskListRecord?
    @State private var tasks: [TaskRecord] = []
    @State private var tagsByTaskId: [String: [TagRecord]] = [:]
    @State private var showQuickAdd = false
    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var groceryDraft = ""
    @State private var hideCheckedGroceries = false
    @AppStorage("list.groupByTag") private var groupByTag = true
    @FocusState private var groceryFieldFocused: Bool

    private let theme = Theme.current

    private var isGroceryList: Bool {
        guard let list else { return false }
        return GroceryMode.isGroceryListName(list.name)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.canvas.ignoresSafeArea()
            content
            if !isGroceryList {
                QuickAddButton { showQuickAdd = true }
                    .padding(20)
            }
        }
        .navigationTitle(list?.name ?? "List")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !isGroceryList {
                        Button {
                            groupByTag.toggle()
                        } label: {
                            Label(
                                groupByTag ? "Ungroup" : "Group by tag",
                                systemImage: groupByTag ? "list.bullet" : "tag"
                            )
                        }
                    }
                    if isGroceryList {
                        Button {
                            hideCheckedGroceries.toggle()
                        } label: {
                            Label(
                                hideCheckedGroceries ? "Show checked" : "Hide checked",
                                systemImage: hideCheckedGroceries ? "eye" : "eye.slash"
                            )
                        }
                    }
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
        .onChange(of: showQuickAdd) { _, open in
            if !open { reload() }
        }
        .onChange(of: showRename) { _, open in
            if !open { reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tickytackyContentDidChange)) { _ in
            reload()
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
        } else if isGroceryList {
            groceryContent
        } else if tasks.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "No tasks here",
                    message: "Tap + to add something to \(list?.name ?? "this list")."
                )
                .padding(20)
            }
        } else if groupByTag {
            groupedTaskList
        } else {
            flatTaskList(tasks)
        }
    }

    // MARK: - Grocery checklist

    private var groceryContent: some View {
        let open = tasks.filter { !$0.isCompleted }
        let checked = tasks.filter(\.isCompleted)
        let visibleChecked = hideCheckedGroceries ? [] : checked

        return List(selection: $selectedTaskIds) {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "cart")
                        .foregroundStyle(theme.accent)
                    TextField("Add item (or paste a list)", text: $groceryDraft, axis: .vertical)
                        .lineLimit(1...6)
                        .focused($groceryFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { addGroceryItems() }
                    Button("Add") { addGroceryItems() }
                        .disabled(groceryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(theme.accent)
                }
            } header: {
                sectionHeader("Checklist")
            } footer: {
                Text("One item per line. Completing an item checks it off.")
                    .foregroundStyle(theme.inkFaint)
            }

            if open.isEmpty && visibleChecked.isEmpty {
                Section {
                    Text(tasks.isEmpty ? "Your cart is empty." : "All checked — nice.")
                        .foregroundStyle(theme.inkMuted)
                        .listRowBackground(theme.canvas)
                }
            }

            if !open.isEmpty {
                Section {
                    ForEach(open) { task in
                        groceryRow(task)
                    }
                    .onDelete { deleteGrocery(open, at: $0) }
                } header: {
                    sectionHeader("To get")
                }
            }

            if !visibleChecked.isEmpty {
                Section {
                    ForEach(visibleChecked) { task in
                        groceryRow(task)
                    }
                    .onDelete { deleteGrocery(visibleChecked, at: $0) }
                } header: {
                    sectionHeader("Checked")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { reload() }
        .onAppear { groceryFieldFocused = true }
    }

    private func groceryRow(_ task: TaskRecord) -> some View {
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

    // MARK: - Standard list

    private func flatTaskList(_ rows: [TaskRecord]) -> some View {
        List(selection: $selectedTaskIds) {
            ForEach(rows) { task in
                taskLink(task)
            }
            .onDelete(perform: softDeleteAtOffsets)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { reload() }
    }

    private var groupedTaskList: some View {
        let sections = TagGrouping.sections(tasks: tasks, tagsByTaskId: tagsByTaskId)
        return List(selection: $selectedTaskIds) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.tasks) { task in
                        taskLink(task)
                    }
                    .onDelete { offsets in
                        softDeleteTasks(in: section.tasks, at: offsets)
                    }
                } header: {
                    sectionHeader(section.title)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { reload() }
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(theme.inkMuted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Data

    private func reload() {
        list = try? database.lists.fetch(id: listId)
        tasks = (try? database.tasks.fetchByList(listId: listId)) ?? []
        tagsByTaskId = (try? database.tags.fetchTagsByTaskIds(tasks.map(\.id))) ?? [:]
    }

    private func toggle(_ task: TaskRecord) {
        _ = try? database.tasks.setCompleted(id: task.id, completed: !task.isCompleted)
        reload()
    }

    private func addGroceryItems() {
        let lines = GroceryMode.splitItemLines(groceryDraft)
        guard !lines.isEmpty else { return }
        for line in lines {
            _ = try? database.tasks.create(title: line, listId: listId)
        }
        groceryDraft = ""
        groceryFieldFocused = true
        reload()
        NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
    }

    private func deleteGrocery(_ source: [TaskRecord], at offsets: IndexSet) {
        for index in offsets {
            try? database.tasks.softDelete(id: source[index].id)
        }
        selectedTaskIds = []
        reload()
    }

    private func softDeleteAtOffsets(_ offsets: IndexSet) {
        softDeleteTasks(in: tasks, at: offsets)
    }

    private func softDeleteTasks(in source: [TaskRecord], at offsets: IndexSet) {
        for index in offsets {
            try? database.tasks.softDelete(id: source[index].id)
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
