import SwiftUI

struct ListEditorSheet: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    enum Mode: Equatable {
        case create
        case rename(TaskListRecord)
    }

    var mode: Mode
    var onSaved: (() -> Void)?

    @State private var name = ""
    @State private var errorMessage: String?

    private let theme = Theme.current

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List name", text: $name)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(theme.accent)
                }
            }
            .onAppear {
                if case .rename(let list) = mode {
                    name = list.name
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .create: "New List"
        case .rename: "Rename List"
        }
    }

    private func save() {
        do {
            switch mode {
            case .create:
                _ = try database.lists.create(name: name)
            case .rename(let list):
                _ = try database.lists.rename(id: list.id, name: name)
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
