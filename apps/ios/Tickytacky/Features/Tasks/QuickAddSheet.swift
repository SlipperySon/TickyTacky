import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    var defaultListId: String?
    var defaultDueDate: Date?
    var onCreated: (() -> Void)?

    @State private var title = ""
    @State private var listId: String = ""
    @State private var lists: [TaskListRecord] = []
    @State private var allTags: [TagRecord] = []
    @State private var selectedTagIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var showGroceryOffer = false
    @FocusState private var titleFocused: Bool

    private let theme = Theme.current

    private var selectedListName: String {
        lists.first(where: { $0.id == listId })?.name ?? "this list"
    }

    private var selectedIsGrocery: Bool {
        lists.first(where: { $0.id == listId })
            .map { GroceryMode.isGroceryListName($0.name) } ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }
                if lists.count > 1 {
                    Section {
                        Picker("List", selection: $listId) {
                            ForEach(lists) { list in
                                Text(list.name).tag(list.id)
                            }
                        }
                    } header: {
                        Text("List")
                    } footer: {
                        Text("Keep lists few (e.g. Life + Groceries). Use tags for classes and projects.")
                            .foregroundStyle(theme.inkFaint)
                    }
                }
                if !allTags.isEmpty && !selectedIsGrocery {
                    Section {
                        ForEach(allTags) { tag in
                            Button {
                                toggleTag(tag.id)
                            } label: {
                                HStack {
                                    TagChip(name: tag.name, isSelected: selectedTagIds.contains(tag.id))
                                    Spacer()
                                    if selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Tags")
                    } footer: {
                        Text("Tags become subheadings when the list is grouped by tag.")
                            .foregroundStyle(theme.inkFaint)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("New Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(theme.accent)
                }
            }
            .confirmationDialog(
                "Add to Groceries?",
                isPresented: $showGroceryOffer,
                titleVisibility: .visible
            ) {
                Button("Add to Groceries") {
                    commitSave(movingToGrocery: true)
                }
                Button("Keep in \(selectedListName)") {
                    commitSave(movingToGrocery: false)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This title mentions grocery. Shopping items stay clearer on a Groceries list.")
            }
            .onAppear {
                loadLists()
                titleFocused = true
            }
        }
    }

    private func loadLists() {
        lists = (try? database.lists.fetchAll()) ?? []
        allTags = (try? database.tags.fetchAll()) ?? []
        if let defaultListId, lists.contains(where: { $0.id == defaultListId }) {
            listId = defaultListId
        } else if let inbox = lists.first(where: \.isInbox) {
            listId = inbox.id
        } else if let first = lists.first {
            listId = first.id
        }
    }

    private func toggleTag(_ id: String) {
        if selectedTagIds.contains(id) {
            selectedTagIds.remove(id)
        } else {
            selectedTagIds.insert(id)
        }
    }

    private func save() {
        guard !listId.isEmpty else {
            errorMessage = "No list available."
            return
        }
        if GroceryMode.titleSuggestsGrocery(title), !selectedIsGrocery {
            showGroceryOffer = true
            return
        }
        commitSave(movingToGrocery: false)
    }

    private func commitSave(movingToGrocery: Bool) {
        do {
            let targetListId: String
            if movingToGrocery {
                targetListId = try GroceryMode.ensureGroceryList(database: database).id
            } else {
                guard !listId.isEmpty else {
                    errorMessage = "No list available."
                    return
                }
                targetListId = listId
            }
            let task = try database.tasks.create(
                title: title,
                listId: targetListId,
                dueDate: defaultDueDate.map { DueDate.startOfDay($0) }
            )
            if !movingToGrocery, !selectedTagIds.isEmpty {
                try database.tags.setTags(forTaskId: task.id, tagIds: Array(selectedTagIds))
            }
            onCreated?()
            NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
