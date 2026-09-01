import SwiftUI

struct TagEditorSheet: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    enum Mode: Equatable {
        case create
        case rename(TagRecord)
    }

    var mode: Mode
    var onSaved: ((TagRecord) -> Void)?

    @State private var name = ""
    @State private var errorMessage: String?

    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $name)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }
                .notebookGroupedRowBackground()
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(theme.danger)
                    }
                    .notebookGroupedRowBackground()
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
                if case .rename(let tag) = mode {
                    name = tag.name
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .create: "New Tag"
        case .rename: "Rename Tag"
        }
    }

    private func save() {
        do {
            let saved: TagRecord
            switch mode {
            case .create:
                saved = try database.tags.create(name: name)
            case .rename(let tag):
                saved = try database.tags.rename(id: tag.id, name: name)
            }
            onSaved?(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
