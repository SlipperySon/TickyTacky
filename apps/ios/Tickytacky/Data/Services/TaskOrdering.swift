import Foundation

/// Shared incomplete-task sort for Today, Upcoming, Search, and tag filters.
///
/// Canonical order (IMPLEMENTATION_MAP / Phase C):
/// 1. **priority** descending (urgent → none)
/// 2. **due time** — dated before undated; earlier `due_date`; timed before untimed;
///    then `due_hour` / `due_minute` ascending
/// 3. **sortOrder** ascending
///
/// When a UI shows completed tasks mixed with open ones, completed rows sort after
/// open rows first, then the same rules apply within each bucket.
///
/// Upcoming day grouping uses `sqlOrderByClauseForUpcoming` (calendar day first, then
/// the canonical rules within each day).
enum TaskOrdering {
    /// SQL `ORDER BY …` for priority → due → sortOrder surfaces.
    static func sqlOrderByClause(includeCompletedBucket: Bool, tableAlias: String = "t") -> String {
        let p = prefix(tableAlias)
        var parts: [String] = []
        if includeCompletedBucket {
            parts.append("\(p)is_completed ASC")
        }
        parts.append(contentsOf: [
            "\(p)priority DESC",
            "CASE WHEN \(p)due_date IS NULL THEN 1 ELSE 0 END ASC",
            "\(p)due_date ASC",
            "\(p)has_due_time DESC",
            "\(p)due_hour ASC",
            "\(p)due_minute ASC",
            "\(p)sort_order ASC",
        ])
        return "ORDER BY " + parts.joined(separator: ", ")
    }

    /// Day-major order so Upcoming can group chronologically, then canonical within day.
    static func sqlOrderByClauseForUpcoming(tableAlias: String = "") -> String {
        let p = prefix(tableAlias)
        return """
        ORDER BY \(p)due_date ASC,
                 \(p)priority DESC,
                 \(p)has_due_time DESC,
                 \(p)due_hour ASC,
                 \(p)due_minute ASC,
                 \(p)sort_order ASC
        """
    }

    /// In-memory sort matching `sqlOrderByClause(includeCompletedBucket: false)`.
    static func sorted(_ tasks: [TaskRecord]) -> [TaskRecord] {
        tasks.sorted(by: compare)
    }

    /// Priority desc → dated before undated → earlier due → timed before untimed → time → sortOrder.
    static func compare(_ lhs: TaskRecord, _ rhs: TaskRecord) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }

        switch (lhs.dueDate, rhs.dueDate) {
        case (nil, .some): return false
        case (.some, nil): return true
        case let (l?, r?) where l != r: return l < r
        default: break
        }

        if lhs.hasDueTime != rhs.hasDueTime { return lhs.hasDueTime && !rhs.hasDueTime }

        let lh = lhs.dueHour ?? Int.max
        let rh = rhs.dueHour ?? Int.max
        if lh != rh { return lh < rh }

        let lm = lhs.dueMinute ?? Int.max
        let rm = rhs.dueMinute ?? Int.max
        if lm != rm { return lm < rm }

        return lhs.sortOrder < rhs.sortOrder
    }

    private static func prefix(_ tableAlias: String) -> String {
        tableAlias.isEmpty ? "" : "\(tableAlias)."
    }
}
