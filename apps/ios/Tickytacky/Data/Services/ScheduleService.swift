import Foundation
import GRDB

/// Schedule / block / exception CRUD against the local GRDB cache. Soft-delete only.
final class ScheduleService: @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Schedules

    func fetchActiveSchedule() throws -> ScheduleRecord? {
        try database.dbQueue.read { db in
            try ScheduleRecord
                .filter(ScheduleRecord.Columns.deletedAt == nil && ScheduleRecord.Columns.isActive == true)
                .order(ScheduleRecord.Columns.createdAt)
                .fetchOne(db)
        }
    }

    func fetchAllSchedules() throws -> [ScheduleRecord] {
        try database.dbQueue.read { db in
            try ScheduleRecord
                .filter(ScheduleRecord.Columns.deletedAt == nil)
                .order(ScheduleRecord.Columns.name)
                .fetchAll(db)
        }
    }

    /// Ensures one active default schedule exists (MVP: single timetable).
    /// Reactivates the oldest non-deleted schedule if none are active; only creates when zero exist.
    @discardableResult
    func ensureDefaultSchedule() throws -> ScheduleRecord {
        if let existing = try fetchActiveSchedule() {
            return existing
        }
        if let oldest = try database.dbQueue.read({ db in
            try ScheduleRecord
                .filter(ScheduleRecord.Columns.deletedAt == nil)
                .order(ScheduleRecord.Columns.createdAt)
                .fetchOne(db)
        }) {
            return try database.dbQueue.write { db in
                var schedule = oldest
                schedule.isActive = true
                schedule.updatedAt = Date()
                try schedule.update(db)
                return schedule
            }
        }
        let now = Date()
        let schedule = ScheduleRecord(
            id: RecordID.make(),
            name: "My Week",
            isActive: true,
            timezone: TimeZone.current.identifier,
            color: PastelSwatch.sage.rawValue,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try schedule.insert(db)
        }
        return schedule
    }

    // MARK: - Blocks

    func fetchBlocks(scheduleId: String) throws -> [ScheduleBlockRecord] {
        try database.dbQueue.read { db in
            try ScheduleBlockRecord
                .filter(
                    ScheduleBlockRecord.Columns.scheduleId == scheduleId
                        && ScheduleBlockRecord.Columns.deletedAt == nil
                )
                .order(
                    ScheduleBlockRecord.Columns.weekday,
                    ScheduleBlockRecord.Columns.startHour,
                    ScheduleBlockRecord.Columns.startMinute
                )
                .fetchAll(db)
        }
    }

    func fetchBlock(id: String) throws -> ScheduleBlockRecord? {
        try database.dbQueue.read { db in
            try ScheduleBlockRecord
                .filter(ScheduleBlockRecord.Columns.id == id && ScheduleBlockRecord.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    @discardableResult
    func createBlock(
        scheduleId: String,
        title: String,
        notes: String? = nil,
        weekday: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        color: String,
        listId: String? = nil,
        reminderMinutesBefore: Int? = nil
    ) throws -> ScheduleBlockRecord {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Title cannot be empty.")
        }
        try ScheduleBlockValidation.validateWeekday(weekday)
        try ScheduleBlockValidation.validate(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
        let now = Date()
        let block = ScheduleBlockRecord(
            id: RecordID.make(),
            scheduleId: scheduleId,
            title: trimmed,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            weekday: weekday,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            color: color,
            listId: listId,
            reminderMinutesBefore: reminderMinutesBefore,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        try database.dbQueue.write { db in
            try block.insert(db)
        }
        notifyRemindersChanged()
        return block
    }

    @discardableResult
    func updateBlock(
        id: String,
        title: String,
        notes: String?,
        weekday: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        color: String,
        listId: String?,
        reminderMinutesBefore: Int?
    ) throws -> ScheduleBlockRecord {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.validation("Title cannot be empty.")
        }
        try ScheduleBlockValidation.validateWeekday(weekday)
        try ScheduleBlockValidation.validate(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
        let block = try database.dbQueue.write { db in
            guard var block = try ScheduleBlockRecord
                .filter(ScheduleBlockRecord.Columns.id == id && ScheduleBlockRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            block.title = trimmed
            block.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            block.weekday = weekday
            block.startHour = startHour
            block.startMinute = startMinute
            block.endHour = endHour
            block.endMinute = endMinute
            block.color = color
            block.listId = listId
            block.reminderMinutesBefore = reminderMinutesBefore
            block.updatedAt = Date()
            try block.update(db)
            return block
        }
        notifyRemindersChanged()
        return block
    }

    func deleteBlock(id: String) throws {
        try database.dbQueue.write { db in
            guard var block = try ScheduleBlockRecord
                .filter(ScheduleBlockRecord.Columns.id == id && ScheduleBlockRecord.Columns.deletedAt == nil)
                .fetchOne(db)
            else {
                throw ServiceError.notFound
            }
            let now = Date()
            block.deletedAt = now
            block.updatedAt = now
            try block.update(db)
        }
        notifyRemindersChanged()
    }

    // MARK: - Exceptions

    func fetchExceptions(blockIds: [String], from: Date, to: Date) throws -> [ScheduleExceptionRecord] {
        guard !blockIds.isEmpty else { return [] }
        return try database.dbQueue.read { db in
            let rows = try ScheduleExceptionRecord
                .filter(
                    blockIds.contains(ScheduleExceptionRecord.Columns.blockId)
                        && ScheduleExceptionRecord.Columns.deletedAt == nil
                )
                .fetchAll(db)
            return rows.filter { exception in
                if exception.originalStart >= from && exception.originalStart < to {
                    return true
                }
                // Reschedule into the visible range (original weekday may be outside).
                guard exception.exceptionType == .reschedule,
                      let newStart = exception.newStart,
                      let newEnd = exception.newEnd
                else { return false }
                return newStart < to && newEnd > from
            }
        }
    }

    @discardableResult
    func skipOccurrence(blockId: String, originalStart: Date) throws -> ScheduleExceptionRecord {
        let record = try upsertException(
            blockId: blockId,
            originalStart: originalStart,
            type: .skip,
            newStart: nil,
            newEnd: nil
        )
        notifyRemindersChanged()
        return record
    }

    @discardableResult
    func rescheduleOccurrence(
        blockId: String,
        originalStart: Date,
        newStart: Date,
        newEnd: Date
    ) throws -> ScheduleExceptionRecord {
        guard newEnd > newStart else {
            throw ServiceError.validation("End time must be after start time.")
        }
        let record = try upsertException(
            blockId: blockId,
            originalStart: originalStart,
            type: .reschedule,
            newStart: newStart,
            newEnd: newEnd
        )
        notifyRemindersChanged()
        return record
    }

    func clearException(blockId: String, originalStart: Date) throws {
        try database.dbQueue.write { db in
            guard var existing = try ScheduleExceptionRecord
                .filter(
                    ScheduleExceptionRecord.Columns.blockId == blockId
                        && ScheduleExceptionRecord.Columns.originalStart == originalStart
                        && ScheduleExceptionRecord.Columns.deletedAt == nil
                )
                .fetchOne(db)
            else { return }
            let now = Date()
            existing.deletedAt = now
            existing.updatedAt = now
            try existing.update(db)
        }
        notifyRemindersChanged()
    }

    // MARK: - Occurrences (service convenience)

    func occurrences(
        forDay day: Date,
        calendar: Calendar = .current
    ) throws -> [ScheduleOccurrence] {
        let dayStart = calendar.startOfDay(for: day)
        let weekday = calendar.component(.weekday, from: dayStart)
        let firstWeekday = calendar.firstWeekday
        let diff = (weekday - firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -diff, to: dayStart) ?? dayStart
        // Expand the whole week so rescheduled-into-this-day slots still appear.
        return try occurrences(weekStarting: weekStart, calendar: calendar)
            .filter { calendar.isDate($0.start, inSameDayAs: dayStart) }
    }

    func occurrences(
        weekStarting weekStart: Date,
        calendar: Calendar = .current
    ) throws -> [ScheduleOccurrence] {
        let schedule = try ensureDefaultSchedule()
        let blocks = try fetchBlocks(scheduleId: schedule.id)
        let start = calendar.startOfDay(for: weekStart)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        // Widen exception window slightly so reschedules into/out of week still resolve.
        let exceptions = try fetchExceptions(
            blockIds: blocks.map(\.id),
            from: start,
            to: end
        )
        return OccurrenceGenerator.occurrences(
            weekStarting: weekStart,
            blocks: blocks.map(ScheduleBlockInput.init(from:)),
            exceptions: exceptions.map(ScheduleExceptionInput.init(from:)),
            calendar: calendar
        )
    }

    /// Days in `[from, to)` that have at least one timetable occurrence (batched by week).
    func daysWithOccurrences(from: Date, to: Date, calendar: Calendar = .current) throws -> Set<Date> {
        let rangeStart = calendar.startOfDay(for: from)
        let rangeEnd = calendar.startOfDay(for: to)
        guard rangeStart < rangeEnd else { return [] }

        let weekday = calendar.component(.weekday, from: rangeStart)
        let firstWeekday = calendar.firstWeekday
        let diff = (weekday - firstWeekday + 7) % 7
        var cursor = calendar.date(byAdding: .day, value: -diff, to: rangeStart) ?? rangeStart
        var days: Set<Date> = []
        while cursor < rangeEnd {
            let weekOcc = try occurrences(weekStarting: cursor, calendar: calendar)
            for occ in weekOcc {
                let day = calendar.startOfDay(for: occ.start)
                if day >= rangeStart, day < rangeEnd {
                    days.insert(day)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    // MARK: - Private

    private func notifyRemindersChanged() {
        let database = self.database
        Task { @MainActor in
            ReminderScheduler.shared.scheduleRefresh(database: database)
        }
    }

    private func upsertException(
        blockId: String,
        originalStart: Date,
        type: ScheduleExceptionType,
        newStart: Date?,
        newEnd: Date?
    ) throws -> ScheduleExceptionRecord {
        try database.dbQueue.write { db in
            let now = Date()
            if var existing = try ScheduleExceptionRecord
                .filter(
                    ScheduleExceptionRecord.Columns.blockId == blockId
                        && ScheduleExceptionRecord.Columns.originalStart == originalStart
                        && ScheduleExceptionRecord.Columns.deletedAt == nil
                )
                .fetchOne(db)
            {
                existing.type = type.rawValue
                existing.newStart = newStart
                existing.newEnd = newEnd
                existing.updatedAt = now
                try existing.update(db)
                return existing
            }
            let record = ScheduleExceptionRecord(
                id: RecordID.make(),
                blockId: blockId,
                originalStart: originalStart,
                type: type.rawValue,
                newStart: newStart,
                newEnd: newEnd,
                notes: nil,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            try record.insert(db)
            return record
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension ScheduleBlockInput {
    init(from record: ScheduleBlockRecord) {
        self.init(
            id: record.id,
            title: record.title,
            notes: record.notes,
            weekday: record.weekday,
            startHour: record.startHour,
            startMinute: record.startMinute,
            endHour: record.endHour,
            endMinute: record.endMinute,
            color: record.color,
            listID: record.listId,
            reminderMinutesBefore: record.reminderMinutesBefore
        )
    }
}

extension ScheduleExceptionInput {
    init(from record: ScheduleExceptionRecord) {
        self.init(
            blockID: record.blockId,
            originalStart: record.originalStart,
            type: record.exceptionType,
            newStart: record.newStart,
            newEnd: record.newEnd
        )
    }
}
