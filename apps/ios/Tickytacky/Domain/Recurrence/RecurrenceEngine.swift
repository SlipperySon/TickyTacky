import Foundation

// MARK: - Completion policy (MVP)
//
// Completing a recurring task advances `due_date` to the next occurrence and keeps
// the same task row (series-only). `is_completed` stays false; optional completion
// log / per-occurrence instances are deferred. See RecurrencePolicy.md.

/// Pure date math for recurring tasks. Always pass an explicit `Calendar`.
enum RecurrenceEngine {
    /// Next due date strictly after `after` (start-of-day), advancing by `rule.interval`
    /// in the rule’s frequency. Month-end clamps via Foundation (e.g. Jan 31 → Feb 28/29).
    ///
    /// MVP weekly ignores `byWeekdays` (same weekday every N weeks from the anchor).
    static func nextDate(after: Date, rule: RecurrenceRule, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: after)
        let step = max(1, rule.interval)
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: step, to: day) ?? day
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * step, to: day) ?? day
        case .monthly:
            return calendar.date(byAdding: .month, value: step, to: day) ?? day
        case .yearly:
            return calendar.date(byAdding: .year, value: step, to: day) ?? day
        }
    }

    /// Occurrences in `[from, to)` using `rule.startDate` as the first candidate,
    /// then stepping with `nextDate`. Caps at `limit` to avoid runaway loops.
    static func occurrences(
        from: Date,
        to: Date,
        rule: RecurrenceRule,
        calendar: Calendar,
        limit: Int = 512
    ) -> [Date] {
        let rangeStart = calendar.startOfDay(for: from)
        let rangeEnd = calendar.startOfDay(for: to)
        guard rangeStart < rangeEnd else { return [] }

        var cursor = calendar.startOfDay(for: rule.startDate)
        // Walk forward until we reach the window (or pass it).
        var guardCount = 0
        while cursor < rangeStart, guardCount < limit {
            cursor = nextDate(after: cursor, rule: rule, calendar: calendar)
            guardCount += 1
        }

        var result: [Date] = []
        while cursor < rangeEnd, result.count < limit {
            if cursor >= rangeStart {
                result.append(cursor)
            }
            cursor = nextDate(after: cursor, rule: rule, calendar: calendar)
        }
        return result
    }

    #if DEBUG
    /// Lightweight matrix check for daily / weekly / monthly (Jan 31) / yearly.
    static func runSelfChecks() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            var c = DateComponents()
            c.year = y; c.month = m; c.day = d
            return cal.startOfDay(for: cal.date(from: c)!)
        }

        let daily = RecurrenceRule(frequency: .daily, interval: 2, startDate: day(2024, 1, 1))
        assert(nextDate(after: day(2024, 1, 1), rule: daily, calendar: cal) == day(2024, 1, 3))

        let weekly = RecurrenceRule(frequency: .weekly, interval: 1, startDate: day(2024, 1, 1))
        assert(nextDate(after: day(2024, 1, 1), rule: weekly, calendar: cal) == day(2024, 1, 8))

        let monthly = RecurrenceRule(frequency: .monthly, interval: 1, startDate: day(2024, 1, 31))
        let feb = nextDate(after: day(2024, 1, 31), rule: monthly, calendar: cal)
        assert(cal.component(.month, from: feb) == 2)
        assert(cal.component(.day, from: feb) == 29) // 2024 leap year

        let yearly = RecurrenceRule(frequency: .yearly, interval: 1, startDate: day(2024, 3, 15))
        assert(nextDate(after: day(2024, 3, 15), rule: yearly, calendar: cal) == day(2025, 3, 15))

        let inRange = occurrences(
            from: day(2024, 1, 1),
            to: day(2024, 1, 8),
            rule: RecurrenceRule(frequency: .daily, interval: 1, startDate: day(2024, 1, 1)),
            calendar: cal
        )
        assert(inRange.count == 7)
    }
    #endif
}
