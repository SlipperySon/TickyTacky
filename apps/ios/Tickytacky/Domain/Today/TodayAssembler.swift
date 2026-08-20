import Foundation

/// Snapshot for the Combined Today surface (Phase F).
///
/// **Section order (UI — do not reorder lightly):**
/// 1. **Overdue** — incomplete tasks with `due_date` before today
/// 2. **Schedule** — today’s timetable occurrences (start time ascending)
/// 3. **Tasks due today** — incomplete tasks due on today
///
/// Pins / undated tasks are out of MVP scope (IMPLEMENTATION_MAP §4.6).
struct TodaySnapshot: Equatable, Sendable {
    var overdue: [TaskRecord]
    var schedule: [ScheduleOccurrence]
    var dueToday: [TaskRecord]

    var isEmpty: Bool {
        overdue.isEmpty && schedule.isEmpty && dueToday.isEmpty
    }
}

/// Pure-ish merge of task lists + schedule occurrences for Today.
/// Callers fetch from `TaskService` / `ScheduleService`; this only sections + sorts.
enum TodayAssembler {
    /// Builds a `TodaySnapshot` with stable sectioning and sorting.
    ///
    /// - Tasks: priority → due time → sortOrder (`TaskOrdering`)
    /// - Occurrences: start ascending, then title (same as `OccurrenceGenerator`)
    static func assemble(
        overdue: [TaskRecord],
        dueToday: [TaskRecord],
        occurrences: [ScheduleOccurrence]
    ) -> TodaySnapshot {
        TodaySnapshot(
            overdue: TaskOrdering.sorted(overdue),
            schedule: Self.sortedOccurrences(occurrences),
            dueToday: TaskOrdering.sorted(dueToday)
        )
    }

    private static func sortedOccurrences(_ occurrences: [ScheduleOccurrence]) -> [ScheduleOccurrence] {
        occurrences.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
