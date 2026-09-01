import SwiftUI

struct ScheduleBlockEditorSheet: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    enum Mode: Equatable {
        case create(scheduleId: String, defaultWeekday: Int)
        case edit(ScheduleBlockRecord)
    }

    var mode: Mode
    var onSaved: (() -> Void)?

    @State private var title = ""
    @State private var weekday = 2
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 10
    @State private var endMinute = 0
    @State private var color = PastelSwatch.sage.rawValue
    @State private var listId: String?
    @State private var hasReminder = false
    @State private var reminderMinutes = 15
    @State private var lists: [TaskListRecord] = []
    @State private var errorMessage: String?

    @Environment(\.theme) private var theme
    private let weekdays = AppCalendar.weekdaysMondayFirst
    private let reminderChoices = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .submitLabel(.done)
                    Picker("Weekday", selection: $weekday) {
                        ForEach(weekdays, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                }
                .notebookGroupedRowBackground()

                Section("Time") {
                    HStack {
                        Text("Start")
                        Spacer()
                        timePickers(hour: $startHour, minute: $startMinute)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        timePickers(hour: $endHour, minute: $endMinute)
                    }
                    Text("Same-day only — overnight blocks aren’t supported yet.")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }
                .notebookGroupedRowBackground()

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(PastelSwatch.allCases) { swatch in
                            Button {
                                color = swatch.rawValue
                            } label: {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(swatch.fill)
                                    .frame(height: 36)
                                    .overlay {
                                        if color == swatch.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(swatch.onFill)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(swatch.displayName)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .notebookGroupedRowBackground()

                Section("List (optional)") {
                    Picker("List", selection: $listId) {
                        Text("None").tag(Optional<String>.none)
                        ForEach(lists) { list in
                            Text(list.name).tag(Optional(list.id))
                        }
                    }
                }
                .notebookGroupedRowBackground()

                Section("Reminder") {
                    Toggle("Remind before start", isOn: $hasReminder)
                        .tint(theme.accent)
                        .onChange(of: hasReminder) { _, enabled in
                            if enabled {
                                Task { await ReminderScheduler.shared.ensureAuthorizedForReminder() }
                            }
                        }
                    if hasReminder {
                        Picker("Minutes before", selection: $reminderMinutes) {
                            ForEach(reminderChoices, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                    }
                }
                .notebookGroupedRowBackground()

                if case .edit = mode {
                    Section {
                        Button("Delete Block", role: .destructive) {
                            deleteBlock()
                        }
                    }
                    .notebookGroupedRowBackground()
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(theme.danger)
                    }
                    .notebookGroupedRowBackground()
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle(navTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(theme.accent)
                }
            }
            .onAppear { load() }
        }
    }

    private var navTitle: String {
        switch mode {
        case .create: "New Block"
        case .edit: "Edit Block"
        }
    }

    @ViewBuilder
    private func timePickers(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Picker("Hour", selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            Text(":")
                .foregroundStyle(theme.inkMuted)
            Picker("Minute", selection: minute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private func load() {
        lists = (try? database.lists.fetchAll()) ?? []
        switch mode {
        case .create(_, let defaultWeekday):
            weekday = defaultWeekday
        case .edit(let block):
            title = block.title
            weekday = block.weekday
            startHour = block.startHour
            startMinute = block.startMinute
            endHour = block.endHour
            endMinute = block.endMinute
            color = block.color
            listId = block.listId
            if let reminder = block.reminderMinutesBefore {
                hasReminder = true
                reminderMinutes = reminder
            }
        }
    }

    private func save() {
        let reminder: Int? = hasReminder ? reminderMinutes : nil
        do {
            switch mode {
            case .create(let scheduleId, _):
                _ = try database.schedules.createBlock(
                    scheduleId: scheduleId,
                    title: title,
                    weekday: weekday,
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    color: color,
                    listId: listId,
                    reminderMinutesBefore: reminder
                )
            case .edit(let block):
                _ = try database.schedules.updateBlock(
                    id: block.id,
                    title: title,
                    notes: block.notes,
                    weekday: weekday,
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    color: color,
                    listId: listId,
                    reminderMinutesBefore: reminder
                )
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteBlock() {
        guard case .edit(let block) = mode else { return }
        do {
            try database.schedules.deleteBlock(id: block.id)
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
