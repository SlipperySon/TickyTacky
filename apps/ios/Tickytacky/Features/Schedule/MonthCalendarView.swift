import SwiftUI

/// Month grid + selected-day detail (tasks due + schedule blocks).
struct MonthCalendarView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.calendar) private var calendar

    @State private var visibleMonth: Date = Date()
    @State private var selectedDay: Date = Date()
    @State private var dayMarks: [Date: DayMark] = [:]
    @State private var dayOccurrences: [ScheduleOccurrence] = []
    @State private var dayTasks: [TaskRecord] = []
    @State private var selectedOccurrence: ScheduleOccurrence?
    @State private var showEditor = false
    @State private var schedule: ScheduleRecord?
    @State private var errorMessage: String?

    @Environment(\.theme) private var theme

    private static let monthFormatter = AppCalendar.monthYear

    private static let weekdaySymbols = AppCalendar.veryShortWeekdaySymbolsMondayFirst

    struct DayMark: Equatable {
        var hasSchedule: Bool
        var hasTasks: Bool
        var isEmpty: Bool { !hasSchedule && !hasTasks }
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                monthGrid
                Divider().overlay(theme.rule)
                dayDetail
                    .frame(minHeight: 160)
                    .layoutPriority(1)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openEditor()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add schedule block")
            }
        }
        .sheet(isPresented: $showEditor) {
            if let schedule {
                ScheduleBlockEditorSheet(
                    mode: .create(
                        scheduleId: schedule.id,
                        defaultWeekday: calendar.component(.weekday, from: selectedDay)
                    )
                ) { reload() }
            }
        }
        .sheet(item: $selectedOccurrence) { occurrence in
            OccurrenceActionsSheet(occurrence: occurrence) { reload() }
        }
        .task { bootstrap() }
        .onChange(of: selectedDay) { _, _ in reloadSelectedDay() }
        .onChange(of: visibleMonth) { _, _ in
            clampSelectedDayToMonth()
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tickytackyContentDidChange)) { _ in
            reload()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(Self.monthFormatter.string(from: visibleMonth))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .foregroundStyle(theme.ink)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.inkFaint)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var monthGrid: some View {
        let days = daysInMonthGrid
        let rows = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let mark = dayMarks[calendar.startOfDay(for: day)]
        return Button {
            selectedDay = calendar.startOfDay(for: day)
            if !inMonth {
                visibleMonth = startOfMonth(containing: day)
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(.body, design: .rounded).weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(inMonth ? theme.ink : theme.inkFaint)
                HStack(spacing: 3) {
                    Circle()
                        .fill(mark?.hasSchedule == true ? theme.accentSecondary : Color.clear)
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(mark?.hasTasks == true ? theme.accent : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? theme.accentSoft : Color.clear)
            }
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.todayMark.opacity(0.6), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(day: day, inMonth: inMonth, mark: mark, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var dayDetail: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(theme.danger)
                .padding(20)
            Spacer()
        } else if dayOccurrences.isEmpty && dayTasks.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "Nothing on this day",
                    message: "No due tasks or timetable blocks for the selected date."
                )
                .padding(20)
            }
        } else {
            List {
                if !dayOccurrences.isEmpty {
                    Section {
                        ForEach(dayOccurrences) { occurrence in
                            Button {
                                selectedOccurrence = occurrence
                            } label: {
                                ScheduleOccurrenceRow(occurrence: occurrence)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(theme.canvas)
                            .listRowSeparatorTint(theme.rule)
                        }
                    } header: {
                        sectionHeader("Schedule")
                    }
                }
                if !dayTasks.isEmpty {
                    Section {
                        ForEach(dayTasks) { task in
                            NavigationLink {
                                TaskDetailView(taskId: task.id)
                            } label: {
                                TaskRow(task: task) {
                                    toggle(task)
                                }
                            }
                            .listRowBackground(theme.canvas)
                            .listRowSeparatorTint(theme.rule)
                        }
                    } header: {
                        sectionHeader("Tasks")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(theme.inkMuted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private var daysInMonthGrid: [Date] {
        let monthStart = startOfMonth(containing: visibleMonth)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else {
            return []
        }
        let days = (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart).map { calendar.startOfDay(for: $0) }
        }
        // Drop trailing weeks that fall entirely outside the visible month (often week 6).
        guard let lastInMonth = days.lastIndex(where: {
            calendar.isDate($0, equalTo: visibleMonth, toGranularity: .month)
        }) else {
            return days
        }
        let weekEnd = ((lastInMonth / 7) + 1) * 7
        return Array(days.prefix(weekEnd))
    }

    private func dayAccessibilityLabel(day: Date, inMonth: Bool, mark: DayMark?, isToday: Bool) -> String {
        var parts = [Self.monthFormatter.string(from: day), "day \(calendar.component(.day, from: day))"]
        if isToday { parts.append("today") }
        if !inMonth { parts.append("outside month") }
        if mark?.hasSchedule == true { parts.append("has schedule") }
        if mark?.hasTasks == true { parts.append("has tasks") }
        if mark == nil || mark?.isEmpty == true { parts.append("empty") }
        return parts.joined(separator: ", ")
    }

    private func bootstrap() {
        visibleMonth = startOfMonth(containing: Date())
        selectedDay = calendar.startOfDay(for: Date())
        reload()
    }

    private func reload() {
        do {
            schedule = try database.schedules.ensureDefaultSchedule()
            rebuildMarks()
            reloadSelectedDay()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildMarks() {
        let days = daysInMonthGrid
        guard let first = days.first, let last = days.last,
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: last)
        else {
            dayMarks = [:]
            return
        }
        let scheduleDays = (try? database.schedules.daysWithOccurrences(
            from: first,
            to: endExclusive,
            calendar: calendar
        )) ?? []
        let taskDays = (try? database.tasks.daysWithDueTasks(
            from: first,
            to: endExclusive,
            calendar: calendar
        )) ?? []
        var marks: [Date: DayMark] = [:]
        for day in days {
            let hasSchedule = scheduleDays.contains(day)
            let hasTasks = taskDays.contains(day)
            if hasSchedule || hasTasks {
                marks[day] = DayMark(hasSchedule: hasSchedule, hasTasks: hasTasks)
            }
        }
        dayMarks = marks
    }

    private func reloadSelectedDay() {
        dayOccurrences = (try? database.schedules.occurrences(forDay: selectedDay, calendar: calendar)) ?? []
        dayTasks = (try? database.tasks.fetchDue(on: selectedDay, calendar: calendar)) ?? []
    }

    private func toggle(_ task: TaskRecord) {
        _ = try? database.tasks.setCompleted(id: task.id, completed: !task.isCompleted)
        reload()
    }

    private func openEditor() {
        if schedule == nil { reload() }
        showEditor = true
    }

    private func shiftMonth(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: startOfMonth(containing: visibleMonth)) else {
            return
        }
        visibleMonth = next
    }

    private func clampSelectedDayToMonth() {
        if !calendar.isDate(selectedDay, equalTo: visibleMonth, toGranularity: .month) {
            let day = min(
                calendar.component(.day, from: selectedDay),
                calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 28
            )
            var comps = calendar.dateComponents([.year, .month], from: visibleMonth)
            comps.day = day
            selectedDay = calendar.startOfDay(for: calendar.date(from: comps) ?? visibleMonth)
        }
    }

    private func startOfMonth(containing date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.startOfDay(for: calendar.date(from: comps) ?? date)
    }
}
