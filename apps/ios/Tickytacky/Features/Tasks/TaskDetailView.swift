import SwiftUI

struct TaskDetailView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    let taskId: String

    @State private var title = ""
    @State private var notes = ""
    @State private var listId = ""
    @State private var priority: Priority = .none
    @State private var lists: [TaskListRecord] = []
    @State private var subtasks: [SubtaskRecord] = []
    @State private var newSubtaskTitle = ""
    @State private var hasDueDate = false
    @State private var dueDateValue = Date()
    @State private var hasDueTime = false
    @State private var dueTimeValue = Date()
    @State private var isCompleted = false
    @State private var loaded = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var allTags: [TagRecord] = []
    @State private var selectedTagIds: Set<String> = []
    @State private var showCreateTag = false
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .weekly
    @State private var recurrenceInterval = 1
    @State private var hasReminder = false
    @State private var reminderOffsetMinutes = 15
    @State private var groceryNudgeDismissed = false

    private let theme = Theme.current
    private let reminderChoices = [0, 5, 15, 30, 60, 120, 1440]

    private var showsGroceryNudge: Bool {
        guard loaded, !groceryNudgeDismissed else { return false }
        guard GroceryMode.titleSuggestsGrocery(title) else { return false }
        let currentIsGrocery = lists.first(where: { $0.id == listId })
            .map { GroceryMode.isGroceryListName($0.name) } ?? false
        return !currentIsGrocery
    }

    var body: some View {
        Group {
            if let errorMessage, !loaded {
                ContentUnavailableView {
                    Label("Task unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.canvas)
            } else if loaded {
                Form {
                    Section {
                        TextField("Title", text: $title)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...8)
                        Toggle("Completed", isOn: $isCompleted)
                            .tint(theme.accent)
                            .onChange(of: isCompleted) { _, newValue in
                                applyCompletion(newValue)
                            }
                    }

                    if showsGroceryNudge {
                        Section {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "cart")
                                    .foregroundStyle(theme.accent)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Move to Groceries?")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.ink)
                                    Text("Titles that mention grocery work best on a shopping checklist.")
                                        .font(.footnote)
                                        .foregroundStyle(theme.inkMuted)
                                    HStack(spacing: 16) {
                                        Button("Move") { moveToGroceryList() }
                                            .tint(theme.accent)
                                        Button("Not now") { groceryNudgeDismissed = true }
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    .padding(.top, 2)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .listRowBackground(theme.accent.opacity(0.08))
                    }

                    Section("Focus") {
                        Button {
                            NotificationCenter.default.post(
                                name: .tickytackyOpenFocus,
                                object: taskId
                            )
                            dismiss()
                        } label: {
                            Label("Start Focus", systemImage: "timer")
                        }
                        .tint(theme.accent)
                        .disabled(isCompleted)
                    }

                    Section("List") {
                        Picker("List", selection: $listId) {
                            ForEach(lists) { list in
                                Text(list.name).tag(list.id)
                            }
                        }
                    }

                    Section {
                        if allTags.isEmpty {
                            Text("No tags yet")
                                .foregroundStyle(theme.inkMuted)
                        } else {
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
                                .accessibilityLabel("\(tag.name), \(selectedTagIds.contains(tag.id) ? "selected" : "not selected")")
                            }
                        }
                        Button {
                            showCreateTag = true
                        } label: {
                            Label("New Tag", systemImage: "plus")
                        }
                        .tint(theme.accent)
                    } header: {
                        Text("Tags")
                    }

                    Section("Due") {
                        Toggle("Due date", isOn: $hasDueDate)
                            .tint(theme.accent)
                        if hasDueDate {
                            DatePicker("Date", selection: $dueDateValue, displayedComponents: .date)
                            Toggle("Time", isOn: $hasDueTime)
                                .tint(theme.accent)
                            if hasDueTime {
                                DatePicker("Time", selection: $dueTimeValue, displayedComponents: .hourAndMinute)
                            }
                        }
                    }

                    Section("Priority") {
                        Picker("Priority", selection: $priority) {
                            ForEach(Priority.allCases) { value in
                                Label {
                                    Text(value.title)
                                } icon: {
                                    PriorityIndicator(priority: value)
                                }
                                .tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Priority \(priority.title)")
                    }

                    Section {
                        Toggle("Repeat", isOn: $isRecurring)
                            .tint(theme.accent)
                            .onChange(of: isRecurring) { _, enabled in
                                if enabled, !hasDueDate {
                                    hasDueDate = true
                                    dueDateValue = DueDate.today()
                                }
                            }
                        if isRecurring {
                            Picker("Frequency", selection: $recurrenceFrequency) {
                                ForEach(RecurrenceFrequency.allCases) { freq in
                                    Text(freq.title).tag(freq)
                                }
                            }
                            Stepper(
                                "Every \(recurrenceInterval) \(recurrenceInterval == 1 ? recurrenceFrequency.intervalUnit : recurrenceFrequency.intervalUnitPlural)",
                                value: $recurrenceInterval,
                                in: 1...99
                            )
                            Text("Edits apply to the whole series. Completing advances the due date.")
                                .font(.footnote)
                                .foregroundStyle(theme.inkMuted)
                        }
                    } header: {
                        Text("Recurrence")
                    }

                    Section {
                        Toggle("Remind me", isOn: $hasReminder)
                            .tint(theme.accent)
                            .disabled(!hasDueDate)
                            .onChange(of: hasReminder) { _, enabled in
                                if enabled {
                                    if !hasDueDate {
                                        hasDueDate = true
                                        dueDateValue = DueDate.today()
                                    }
                                    Task { await ReminderScheduler.shared.ensureAuthorizedForReminder() }
                                }
                            }
                        if hasReminder {
                            Picker("When", selection: $reminderOffsetMinutes) {
                                ForEach(reminderChoices, id: \.self) { minutes in
                                    Text(Self.reminderLabel(minutes)).tag(minutes)
                                }
                            }
                            if !hasDueTime {
                                Text("Without a due time, reminders use 9:00 on the due day.")
                                    .font(.footnote)
                                    .foregroundStyle(theme.inkMuted)
                            }
                        }
                    } header: {
                        Text("Reminder")
                    }

                    Section("Subtasks") {
                        ForEach(subtasks) { sub in
                            HStack(spacing: 12) {
                                SageCheckbox(
                                    isOn: sub.isCompleted,
                                    title: sub.title,
                                    accessibilityHidden: true
                                ) {
                                    toggleSubtask(sub)
                                }
                                Text(sub.title)
                                    .foregroundStyle(sub.isCompleted ? theme.inkFaint : theme.ink)
                                    .strikethrough(sub.isCompleted, color: theme.inkFaint)
                                Spacer()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(sub.title), \(sub.isCompleted ? "completed" : "incomplete")")
                            .accessibilityAction(named: Text("Toggle completion")) {
                                toggleSubtask(sub)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSubtask(sub)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        HStack {
                            TextField("Add subtask", text: $newSubtaskTitle)
                                .submitLabel(.done)
                                .onSubmit { addSubtask() }
                            Button("Add") { addSubtask() }
                                .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .tint(theme.accent)
                        }
                    }

                    Section {
                        Button("Delete Task", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(theme.danger)
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .navigationTitle("Task")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if loaded { persist() }
                    dismiss()
                }
                .tint(theme.accent)
            }
        }
        .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteTask() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCreateTag) {
            TagEditorSheet(mode: .create) { tag in
                selectedTagIds.insert(tag.id)
                allTags = (try? database.tags.fetchAll()) ?? allTags
            }
        }
        .task { load() }
        .onDisappear { if loaded { persist() } }
    }

    private func load() {
        do {
            lists = try database.lists.fetchAll()
            allTags = try database.tags.fetchAll()
            guard let task = try database.tasks.fetch(id: taskId) else {
                errorMessage = "Task not found."
                return
            }
            title = task.title
            notes = task.notes ?? ""
            listId = task.listId
            priority = task.priorityValue
            isCompleted = task.isCompleted
            subtasks = try database.tasks.fetchSubtasks(taskId: taskId)
            selectedTagIds = Set(try database.tags.fetchTags(forTaskId: taskId).map(\.id))
            if let due = task.dueDate {
                hasDueDate = true
                dueDateValue = due
            } else {
                hasDueDate = false
                dueDateValue = DueDate.today()
            }
            hasDueTime = task.hasDueTime
            if task.hasDueTime, let hour = task.dueHour, let minute = task.dueMinute {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = hour
                comps.minute = minute
                dueTimeValue = Calendar.current.date(from: comps) ?? Date()
            }
            if let rule = task.recurrenceRule {
                isRecurring = true
                recurrenceFrequency = rule.frequency
                recurrenceInterval = max(1, rule.interval)
            } else {
                isRecurring = false
                recurrenceFrequency = .weekly
                recurrenceInterval = 1
            }
            let offsets = task.reminderOffsetsMinutes
            if let first = offsets.first {
                hasReminder = true
                reminderOffsetMinutes = first
            } else {
                hasReminder = false
                reminderOffsetMinutes = 15
            }
            loaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist() {
        guard var task = try? database.tasks.fetch(id: taskId) else { return }
        task.title = title
        task.notes = notes
        task.listId = listId
        task.priorityValue = priority
        if hasDueDate {
            task.dueDate = DueDate.startOfDay(dueDateValue)
            task.hasDueTime = hasDueTime
            if hasDueTime {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: dueTimeValue)
                task.dueHour = comps.hour
                task.dueMinute = comps.minute
            } else {
                task.dueHour = nil
                task.dueMinute = nil
            }
        } else {
            task.dueDate = nil
            task.hasDueTime = false
            task.dueHour = nil
            task.dueMinute = nil
            hasReminder = false
        }
        if isRecurring {
            let existingStart = task.recurrenceRule?.startDate
            let start = existingStart ?? task.dueDate ?? DueDate.today()
            task.recurrenceRule = RecurrenceRule(
                frequency: recurrenceFrequency,
                interval: recurrenceInterval,
                startDate: start
            )
            if task.dueDate == nil {
                let due = DueDate.startOfDay(start)
                task.dueDate = due
                hasDueDate = true
                dueDateValue = due
            }
        } else {
            task.recurrenceRule = nil
        }
        task.reminderOffsetsMinutes = (hasReminder && hasDueDate) ? [reminderOffsetMinutes] : []
        do {
            _ = try database.tasks.update(task)
            try database.tags.setTags(forTaskId: taskId, tagIds: Array(selectedTagIds))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func reminderLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "At due time"
        case 5: return "5 minutes before"
        case 15: return "15 minutes before"
        case 30: return "30 minutes before"
        case 60: return "1 hour before"
        case 120: return "2 hours before"
        case 1440: return "1 day before"
        default:
            if minutes < 60 { return "\(minutes) minutes before" }
            if minutes % 60 == 0 { return "\(minutes / 60) hours before" }
            return "\(minutes) minutes before"
        }
    }

    private func applyCompletion(_ completed: Bool) {
        do {
            let updated = try database.tasks.setCompleted(id: taskId, completed: completed)
            isCompleted = updated.isCompleted
            if let due = updated.dueDate {
                hasDueDate = true
                dueDateValue = due
            }
        } catch {
            errorMessage = error.localizedDescription
            isCompleted = !completed
        }
    }

    private func moveToGroceryList() {
        do {
            let grocery = try GroceryMode.ensureGroceryList(database: database)
            listId = grocery.id
            lists = try database.lists.fetchAll()
            groceryNudgeDismissed = true
            persist()
            NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleTag(_ id: String) {
        if selectedTagIds.contains(id) {
            selectedTagIds.remove(id)
        } else {
            selectedTagIds.insert(id)
        }
    }

    private func addSubtask() {
        do {
            _ = try database.tasks.addSubtask(taskId: taskId, title: newSubtaskTitle)
            newSubtaskTitle = ""
            subtasks = try database.tasks.fetchSubtasks(taskId: taskId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleSubtask(_ sub: SubtaskRecord) {
        do {
            _ = try database.tasks.setSubtaskCompleted(id: sub.id, completed: !sub.isCompleted)
            subtasks = try database.tasks.fetchSubtasks(taskId: taskId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSubtask(_ sub: SubtaskRecord) {
        do {
            try database.tasks.softDeleteSubtask(id: sub.id)
            subtasks = try database.tasks.fetchSubtasks(taskId: taskId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTask() {
        persist()
        do {
            try database.tasks.softDelete(id: taskId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
