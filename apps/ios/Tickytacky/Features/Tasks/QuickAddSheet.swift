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
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private let theme = Theme.current

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
                    Section("List") {
                        Picker("List", selection: $listId) {
                            ForEach(lists) { list in
                                Text(list.name).tag(list.id)
                            }
                        }
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
            .onAppear {
                loadLists()
                titleFocused = true
            }
        }
    }

    private func loadLists() {
        lists = (try? database.lists.fetchAll()) ?? []
        if let defaultListId, lists.contains(where: { $0.id == defaultListId }) {
            listId = defaultListId
        } else if let inbox = lists.first(where: \.isInbox) {
            listId = inbox.id
        } else if let first = lists.first {
            listId = first.id
        }
    }

    private func save() {
        guard !listId.isEmpty else {
            errorMessage = "No list available."
            return
        }
        do {
            _ = try database.tasks.create(
                title: title,
                listId: listId,
                dueDate: defaultDueDate.map { DueDate.startOfDay($0) }
            )
            onCreated?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
