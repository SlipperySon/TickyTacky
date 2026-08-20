import Foundation

/// Expands weekly schedule blocks into concrete occurrences for a date range.
/// Pure value logic — pass an explicit `Calendar` (tests must not rely on device TZ).
enum OccurrenceGenerator {
    /// Inclusive `from` start-of-day through exclusive `to` (typical: next day after range end).
    /// Skipped exceptions are omitted. Rescheduled occurrences use `newStart`/`newEnd`.
    static func occurrences(
        blocks: [ScheduleBlockInput],
        exceptions: [ScheduleExceptionInput],
        from: Date,
        to: Date,
        calendar: Calendar
    ) -> [ScheduleOccurrence] {
        guard from < to else { return [] }

        let exceptionIndex = Dictionary(
            grouping: exceptions,
            by: { ExceptionKey(blockID: $0.blockID, originalStart: $0.originalStart) }
        )

        var results: [ScheduleOccurrence] = []
        var day = calendar.startOfDay(for: from)
        let endBound = to

        while day < endBound {
            let weekday = calendar.component(.weekday, from: day)
            for block in blocks where block.weekday == weekday {
                guard let originalStart = calendar.date(
                    bySettingHour: block.startHour,
                    minute: block.startMinute,
                    second: 0,
                    of: day
                ),
                let originalEnd = calendar.date(
                    bySettingHour: block.endHour,
                    minute: block.endMinute,
                    second: 0,
                    of: day
                )
                else { continue }

                let key = ExceptionKey(blockID: block.id, originalStart: originalStart)
                let matched = exceptionIndex[key]?.last

                if let matched, matched.type == .skip {
                    continue
                }

                var start = originalStart
                var end = originalEnd
                var applied = false
                if let matched, matched.type == .reschedule,
                   let newStart = matched.newStart,
                   let newEnd = matched.newEnd
                {
                    start = newStart
                    end = newEnd
                    applied = true
                }

                // Include if the occurrence interval intersects [from, to).
                guard start < endBound, end > from else { continue }

                results.append(
                    ScheduleOccurrence(
                        id: ScheduleOccurrence.makeID(blockID: block.id, originalStart: originalStart),
                        blockID: block.id,
                        title: block.title,
                        notes: block.notes,
                        start: start,
                        end: end,
                        originalStart: originalStart,
                        color: block.color,
                        listID: block.listID,
                        isExceptionApplied: applied,
                        reminderMinutesBefore: block.reminderMinutesBefore
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        // Reschedules whose original weekday falls outside [from, to) still appear when
        // newStart/newEnd intersect the query range.
        let emittedOriginalStarts = Set(results.map { ExceptionKey(blockID: $0.blockID, originalStart: $0.originalStart) })
        let blocksByID = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })
        for exception in exceptions where exception.type == .reschedule {
            guard let newStart = exception.newStart,
                  let newEnd = exception.newEnd,
                  newStart < endBound,
                  newEnd > from
            else { continue }
            let key = ExceptionKey(blockID: exception.blockID, originalStart: exception.originalStart)
            guard !emittedOriginalStarts.contains(key),
                  let block = blocksByID[exception.blockID]
            else { continue }
            results.append(
                ScheduleOccurrence(
                    id: ScheduleOccurrence.makeID(blockID: block.id, originalStart: exception.originalStart),
                    blockID: block.id,
                    title: block.title,
                    notes: block.notes,
                    start: newStart,
                    end: newEnd,
                    originalStart: exception.originalStart,
                    color: block.color,
                    listID: block.listID,
                    isExceptionApplied: true,
                    reminderMinutesBefore: block.reminderMinutesBefore
                )
            )
        }

        return results.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    static func occurrences(
        forDay day: Date,
        blocks: [ScheduleBlockInput],
        exceptions: [ScheduleExceptionInput],
        calendar: Calendar
    ) -> [ScheduleOccurrence] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return occurrences(blocks: blocks, exceptions: exceptions, from: start, to: end, calendar: calendar)
    }

    static func occurrences(
        weekStarting weekStart: Date,
        blocks: [ScheduleBlockInput],
        exceptions: [ScheduleExceptionInput],
        calendar: Calendar
    ) -> [ScheduleOccurrence] {
        let start = calendar.startOfDay(for: weekStart)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return occurrences(blocks: blocks, exceptions: exceptions, from: start, to: end, calendar: calendar)
    }

    private struct ExceptionKey: Hashable {
        var blockID: String
        var originalStart: Date
    }
}
