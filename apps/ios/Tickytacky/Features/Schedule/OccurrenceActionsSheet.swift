import SwiftUI

/// Skip / reschedule a single occurrence, or edit the series block.
struct OccurrenceActionsSheet: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    var occurrence: ScheduleOccurrence
    var onChanged: (() -> Void)?

    @State private var showReschedule = false
    @State private var showEditBlock = false
    @State private var block: ScheduleBlockRecord?
    @State private var newStart = Date()
    @State private var newEnd = Date()
    @State private var errorMessage: String?

    @Environment(\.theme) private var theme

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppCalendar.locale
        f.calendar = AppCalendar.gregorian
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(occurrence.title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text("\(Self.timeFormatter.string(from: occurrence.start)) – \(Self.timeFormatter.string(from: occurrence.end))")
                        .foregroundStyle(theme.inkMuted)
                    if occurrence.isExceptionApplied {
                        Text("This occurrence was rescheduled.")
                            .font(.caption)
                            .foregroundStyle(theme.accentSecondary)
                    }
                }
                .notebookGroupedRowBackground()

                Section {
                    Button("Skip this occurrence") {
                        skip()
                    }
                    Button("Reschedule this occurrence") {
                        newStart = occurrence.start
                        newEnd = occurrence.end
                        showReschedule = true
                    }
                    if occurrence.isExceptionApplied {
                        Button("Restore original time") {
                            clearException()
                        }
                    }
                }
                .notebookGroupedRowBackground()

                Section {
                    Button("Edit weekly block") {
                        loadBlockAndEdit()
                    }
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
            .navigationTitle("Occurrence")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showReschedule) {
                rescheduleForm
            }
            .sheet(isPresented: $showEditBlock) {
                if let block {
                    ScheduleBlockEditorSheet(mode: .edit(block)) {
                        onChanged?()
                        dismiss()
                    }
                }
            }
        }
    }

    private var rescheduleForm: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("New start", selection: $newStart)
                    DatePicker("New end", selection: $newEnd)
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
            .navigationTitle("Reschedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showReschedule = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { reschedule() }
                        .tint(theme.accent)
                }
            }
        }
    }

    private func skip() {
        do {
            _ = try database.schedules.skipOccurrence(
                blockId: occurrence.blockID,
                originalStart: occurrence.originalStart
            )
            onChanged?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reschedule() {
        do {
            _ = try database.schedules.rescheduleOccurrence(
                blockId: occurrence.blockID,
                originalStart: occurrence.originalStart,
                newStart: newStart,
                newEnd: newEnd
            )
            showReschedule = false
            onChanged?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearException() {
        do {
            try database.schedules.clearException(
                blockId: occurrence.blockID,
                originalStart: occurrence.originalStart
            )
            onChanged?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadBlockAndEdit() {
        do {
            block = try database.schedules.fetchBlock(id: occurrence.blockID)
            guard block != nil else {
                errorMessage = "Block not found."
                return
            }
            showEditBlock = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
