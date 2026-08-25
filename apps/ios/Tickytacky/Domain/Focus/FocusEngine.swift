import Foundation
import Observation

/// Runs the active Pomodoro timer. Local-only; end fires via notification when backgrounded.
@MainActor
@Observable
final class FocusEngine {
    static let shared = FocusEngine()

    private(set) var phase: FocusSessionKind = .work
    private(set) var isRunning = false
    private(set) var remainingSeconds: Int = FocusSettings.durationSeconds(for: .work)
    private(set) var plannedSeconds: Int = FocusSettings.durationSeconds(for: .work)
    private(set) var activeSessionId: String?
    private(set) var linkedTaskId: String?
    private(set) var linkedTaskTitle: String?
    private(set) var completedWorkInCycle = 0
    private(set) var lastError: String?

    /// When set, Focus tab should pre-select this task on appear.
    var pendingTaskId: String?

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?
    private let database: AppDatabase

    private init(database: AppDatabase = .shared) {
        self.database = database
        plannedSeconds = FocusSettings.durationSeconds(for: .work)
        remainingSeconds = plannedSeconds
    }

    var progress: Double {
        guard plannedSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(plannedSeconds))
    }

    var timeLabel: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func prepare(taskId: String?) {
        pendingTaskId = taskId.map(RecordID.normalize)
        if !isRunning, let pendingTaskId {
            linkTask(id: pendingTaskId)
        }
    }

    func applyPendingTaskIfNeeded() {
        guard let pendingTaskId else { return }
        if !isRunning {
            linkTask(id: pendingTaskId)
        }
        self.pendingTaskId = nil
    }

    func linkTask(id: String?) {
        guard !isRunning else { return }
        linkedTaskId = id.map(RecordID.normalize)
        if let linkedTaskId {
            linkedTaskTitle = (try? database.tasks.fetch(id: linkedTaskId))?.title
        } else {
            linkedTaskTitle = nil
        }
    }

    func clearLinkedTask() {
        guard !isRunning else { return }
        linkedTaskId = nil
        linkedTaskTitle = nil
    }

    func selectPhase(_ kind: FocusSessionKind) {
        guard !isRunning else { return }
        phase = kind
        plannedSeconds = FocusSettings.durationSeconds(for: kind)
        remainingSeconds = plannedSeconds
        endDate = nil
    }

    func reloadDurationsFromSettings() {
        guard !isRunning else { return }
        plannedSeconds = FocusSettings.durationSeconds(for: phase)
        remainingSeconds = plannedSeconds
    }

    func start() async {
        lastError = nil
        guard !isRunning else { return }

        if remainingSeconds <= 0 {
            remainingSeconds = FocusSettings.durationSeconds(for: phase)
            plannedSeconds = remainingSeconds
        }

        do {
            let session = try database.focus.start(
                kind: phase,
                plannedSeconds: remainingSeconds,
                taskId: phase == .work ? linkedTaskId : nil
            )
            activeSessionId = session.id
            isRunning = true
            endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            await ReminderScheduler.shared.ensureAuthorizedForReminder()
            await ReminderScheduler.shared.scheduleFocusEnd(
                sessionId: session.id,
                fireDate: endDate!,
                title: phase.isBreak ? "Break over" : "Focus complete",
                body: phase.isBreak
                    ? "Ready for another focus block?"
                    : (linkedTaskTitle.map { "“\($0)” — time for a break." } ?? "Time for a break.")
            )
            startTicking()
        } catch {
            lastError = error.localizedDescription
            isRunning = false
            activeSessionId = nil
            endDate = nil
        }
    }

    func pause() {
        guard isRunning else { return }
        syncRemainingFromEndDate()
        isRunning = false
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        if let activeSessionId {
            ReminderScheduler.shared.cancelFocusEnd(sessionId: activeSessionId)
        }
    }

    func resume() async {
        guard !isRunning, remainingSeconds > 0, activeSessionId != nil else {
            await start()
            return
        }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        if let activeSessionId, let endDate {
            await ReminderScheduler.shared.ensureAuthorizedForReminder()
            await ReminderScheduler.shared.scheduleFocusEnd(
                sessionId: activeSessionId,
                fireDate: endDate,
                title: phase.isBreak ? "Break over" : "Focus complete",
                body: phase.isBreak
                    ? "Ready for another focus block?"
                    : (linkedTaskTitle.map { "“\($0)” — time for a break." } ?? "Time for a break.")
            )
        }
        startTicking()
    }

    func skip() async {
        await finish(completed: false, autoAdvance: true)
    }

    func resetIdle() {
        guard !isRunning else { return }
        if let activeSessionId {
            try? database.focus.markEnded(id: activeSessionId)
            ReminderScheduler.shared.cancelFocusEnd(sessionId: activeSessionId)
        }
        activeSessionId = nil
        endDate = nil
        plannedSeconds = FocusSettings.durationSeconds(for: phase)
        remainingSeconds = plannedSeconds
    }

    /// Call when scene becomes active so remaining time stays accurate.
    func refreshFromClock() {
        guard isRunning else { return }
        syncRemainingFromEndDate()
        if remainingSeconds <= 0 {
            Task { await finish(completed: true, autoAdvance: true) }
        }
    }

    // MARK: - Private

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, !Task.isCancelled else { return }
                self.syncRemainingFromEndDate()
                if self.remainingSeconds <= 0 {
                    await self.finish(completed: true, autoAdvance: true)
                    return
                }
            }
        }
    }

    private func syncRemainingFromEndDate() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    private func finish(completed: Bool, autoAdvance: Bool) async {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
        endDate = nil

        let sessionId = activeSessionId
        if let sessionId {
            ReminderScheduler.shared.cancelFocusEnd(sessionId: sessionId)
            if completed {
                try? database.focus.markCompleted(id: sessionId)
            } else {
                try? database.focus.markEnded(id: sessionId)
            }
        }
        activeSessionId = nil

        let finishedPhase = phase
        if completed && finishedPhase == .work {
            completedWorkInCycle += 1
        }

        remainingSeconds = 0

        guard autoAdvance else {
            plannedSeconds = FocusSettings.durationSeconds(for: phase)
            remainingSeconds = plannedSeconds
            return
        }

        let next = nextPhase(after: finishedPhase, completedWork: completedWorkInCycle)
        phase = next
        plannedSeconds = FocusSettings.durationSeconds(for: next)
        remainingSeconds = plannedSeconds

        let shouldAutoStart: Bool
        if next.isBreak {
            shouldAutoStart = FocusSettings.autoStartBreak
        } else {
            shouldAutoStart = FocusSettings.autoStartWork
        }
        if shouldAutoStart {
            await start()
        }
    }

    private func nextPhase(after finished: FocusSessionKind, completedWork: Int) -> FocusSessionKind {
        switch finished {
        case .work:
            if completedWork > 0, completedWork % FocusSettings.sessionsUntilLongBreak == 0 {
                return .longBreak
            }
            return .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }
}
