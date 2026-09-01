import SwiftUI

struct FocusView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.scenePhase) private var scenePhase

    var embedsNavigationStack: Bool = true

    @State private var engine = FocusEngine.shared
    @State private var showTaskPicker = false
    @State private var todaySessions: [FocusSessionRecord] = []
    @State private var completedWorkToday = 0

    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { root }
            } else {
                root
            }
        }
    }

    private var root: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                phasePicker
                timerCard
                linkedTaskRow
                controls
                if let error = engine.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(theme.danger)
                }
                todaySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Focus")
        .sheet(isPresented: $showTaskPicker) {
            FocusTaskPicker { task in
                engine.linkTask(id: task?.id)
            }
        }
        .onAppear {
            engine.applyPendingTaskIfNeeded()
            engine.reloadDurationsFromSettings()
            reloadToday()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.refreshFromClock()
                reloadToday()
            }
        }
        .onChange(of: engine.isRunning) { _, _ in
            reloadToday()
        }
        .onChange(of: engine.completedWorkInCycle) { _, _ in
            reloadToday()
        }
    }

    private var phasePicker: some View {
        Picker("Phase", selection: Binding(
            get: { engine.phase },
            set: { engine.selectPhase($0) }
        )) {
            Text("Focus").tag(FocusSessionKind.work)
            Text("Short").tag(FocusSessionKind.shortBreak)
            Text("Long").tag(FocusSessionKind.longBreak)
        }
        .pickerStyle(.segmented)
        .disabled(engine.isRunning)
        .accessibilityLabel("Session type")
    }

    private var timerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(theme.rule, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.001, engine.progress))
                    .stroke(
                        engine.phase.isBreak ? theme.accentSecondary : theme.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: engine.progress)
                VStack(spacing: 6) {
                    Text(engine.phase.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(theme.inkMuted)
                    Text(engine.timeLabel)
                        .font(.system(size: 52, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
                        .accessibilityLabel("\(engine.remainingSeconds / 60) minutes \(engine.remainingSeconds % 60) seconds remaining")
                }
            }
            .frame(width: 240, height: 240)
            .frame(maxWidth: .infinity)

            Text(cycleCaption)
                .font(.footnote)
                .foregroundStyle(theme.inkFaint)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }

    private var cycleCaption: String {
        let untilLong = FocusSettings.sessionsUntilLongBreak
        let inCycle = engine.completedWorkInCycle % untilLong
        return "Today \(completedWorkToday) focus · Cycle \(inCycle)/\(untilLong)"
    }

    private var linkedTaskRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked task")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.ink)
            HStack {
                Button {
                    showTaskPicker = true
                } label: {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundStyle(theme.accentSecondary)
                        Text(engine.linkedTaskTitle ?? "None — optional")
                            .foregroundStyle(engine.linkedTaskTitle == nil ? theme.inkFaint : theme.ink)
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)
                .disabled(engine.isRunning)
                .accessibilityHint(engine.isRunning ? "Task locked while running" : "Choose a task to focus on")

                if engine.linkedTaskId != nil, !engine.isRunning {
                    Button("Clear") {
                        engine.clearLinkedTask()
                    }
                    .font(.footnote)
                    .tint(theme.accentSecondary)
                }
            }
            .padding(12)
            .background(theme.surfaceInk)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if engine.isRunning {
                Button {
                    engine.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Button {
                    Task { await engine.skip() }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.inkMuted)
            } else if engine.activeSessionId != nil, engine.remainingSeconds > 0, engine.remainingSeconds < engine.plannedSeconds {
                Button {
                    Task { await engine.resume() }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)

                Button {
                    engine.resetIdle()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.inkMuted)
            } else {
                Button {
                    Task { await engine.start() }
                } label: {
                    Label(engine.phase.isBreak ? "Start break" : "Start focus", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.phase.isBreak ? theme.accentSecondary : theme.accent)
            }
        }
        .font(.system(.body, design: .rounded).weight(.semibold))
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.ink)
            if todaySessions.isEmpty {
                EmptyStateView(
                    title: "No sessions yet",
                    message: "Start a focus block — it’ll show up here when you finish."
                )
            } else {
                ForEach(todaySessions.prefix(8)) { session in
                    HStack {
                        Circle()
                            .fill(session.kindValue.isBreak ? theme.accentSecondary : theme.accent)
                            .frame(width: 8, height: 8)
                        Text(session.kindValue.title)
                            .foregroundStyle(theme.ink)
                        Spacer()
                        Text(durationLabel(session))
                            .foregroundStyle(theme.inkMuted)
                            .monospacedDigit()
                        Text(session.didComplete ? "Done" : "Ended")
                            .font(.caption)
                            .foregroundStyle(session.didComplete ? theme.accent : theme.inkFaint)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.top, 8)
    }

    private func durationLabel(_ session: FocusSessionRecord) -> String {
        let mins = max(1, session.plannedSeconds / 60)
        return "\(mins)m"
    }

    private func reloadToday() {
        todaySessions = (try? database.focus.fetchToday()) ?? []
        completedWorkToday = (try? database.focus.completedWorkCountToday()) ?? 0
    }
}

private struct FocusTaskPicker: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss

    var onPick: (TaskRecord?) -> Void

    @State private var tasks: [TaskRecord] = []
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onPick(nil)
                    dismiss()
                } label: {
                    Text("No linked task")
                        .foregroundStyle(theme.inkMuted)
                }
                .listRowBackground(theme.canvas)
                ForEach(tasks) { task in
                    Button {
                        onPick(task)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .foregroundStyle(theme.ink)
                            if let due = task.dueDate {
                                Text(due.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(theme.inkFaint)
                            }
                        }
                    }
                    .listRowBackground(theme.canvas)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("Link task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { load() }
        }
    }

    private func load() {
        let today = (try? database.tasks.fetchToday()) ?? (overdue: [], dueToday: [])
        var seen = Set<String>()
        var ordered: [TaskRecord] = []
        for task in today.overdue + today.dueToday {
            if seen.insert(task.id).inserted {
                ordered.append(task)
            }
        }
        if let upcoming = try? database.tasks.fetchUpcoming(days: 14) {
            for group in upcoming {
                for task in group.tasks where seen.insert(task.id).inserted {
                    ordered.append(task)
                }
            }
        }
        if let inbox = try? database.fetchInbox(),
           let inboxTasks = try? database.tasks.fetchByList(listId: inbox.id, includeCompleted: false) {
            for task in inboxTasks where seen.insert(task.id).inserted {
                ordered.append(task)
            }
        }
        tasks = ordered
    }
}
