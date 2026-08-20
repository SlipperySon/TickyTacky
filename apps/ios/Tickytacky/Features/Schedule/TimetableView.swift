import SwiftUI

/// Weekly timetable: day strip + agenda-by-day (Phase E). Grid deferred.
struct TimetableView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.calendar) private var calendar

    var embedsNavigationStack: Bool = true

    @State private var weekStart: Date = Date()
    @State private var selectedDay: Date = Date()
    @State private var schedule: ScheduleRecord?
    @State private var dayOccurrences: [ScheduleOccurrence] = []
    @State private var weekDayCounts: [Date: Int] = [:]
    @State private var showEditor = false
    @State private var selectedOccurrence: ScheduleOccurrence?
    @State private var errorMessage: String?

    private let theme = Theme.current

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

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
        ZStack {
            theme.canvas.ignoresSafeArea()
            HStack(spacing: 0) {
                theme.canvasRuled
                    .frame(width: 14)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    weekHeader
                    weekStrip
                    Divider().overlay(theme.rule)
                    agenda
                }
            }
        }
        .navigationTitle("Timetable")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openEditor()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add schedule block")
                .disabled(schedule == nil && errorMessage != nil)
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
            } else {
                NavigationStack {
                    EmptyStateView(
                        title: "Schedule unavailable",
                        message: errorMessage ?? "Could not load the default timetable."
                    )
                    .padding(20)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showEditor = false }
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedOccurrence) { occurrence in
            OccurrenceActionsSheet(occurrence: occurrence) { reload() }
        }
        .task { bootstrap() }
        .onChange(of: selectedDay) { _, _ in reloadDay() }
        .onChange(of: weekStart) { _, _ in
            clampSelectedDayToWeek()
            reload()
        }
    }

    private var weekHeader: some View {
        HStack {
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous week")

            Spacer()

            Text(weekTitle)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next week")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .foregroundStyle(theme.ink)
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(daysInWeek, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                let isToday = calendar.isDateInToday(day)
                let count = weekDayCounts[calendar.startOfDay(for: day)] ?? 0
                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: 4) {
                        Text(Self.dayFormatter.string(from: day))
                            .font(.caption2.weight(.medium))
                        Text(Self.dayNumberFormatter.string(from: day))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Circle()
                            .fill(count > 0 ? theme.accent : .clear)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(isSelected ? theme.ink : theme.inkMuted)
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
                .accessibilityLabel(dayAccessibilityLabel(day: day, count: count, isToday: isToday))
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var agenda: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(theme.danger)
                .padding(20)
            Spacer()
        } else if dayOccurrences.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "Nothing scheduled",
                    message: "Add your weekly classes or routines."
                )
                .padding(20)
            }
        } else {
            List {
                ForEach(dayOccurrences) { occurrence in
                    Button {
                        selectedOccurrence = occurrence
                    } label: {
                        ScheduleOccurrenceRow(occurrence: occurrence)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.canvas)
                    .listRowSeparatorTint(theme.rule)
                    .accessibilityHint("Opens occurrence actions")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var daysInWeek: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private var weekTitle: String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return Self.weekRangeFormatter.string(from: weekStart)
        }
        return "\(Self.weekRangeFormatter.string(from: weekStart)) – \(Self.weekRangeFormatter.string(from: end))"
    }

    private func dayAccessibilityLabel(day: Date, count: Int, isToday: Bool) -> String {
        var parts = [
            Self.dayFormatter.string(from: day),
            Self.dayNumberFormatter.string(from: day)
        ]
        if isToday { parts.append("today") }
        if count == 0 {
            parts.append("no events")
        } else if count == 1 {
            parts.append("1 event")
        } else {
            parts.append("\(count) events")
        }
        return parts.joined(separator: ", ")
    }

    private func openEditor() {
        if schedule == nil {
            reload()
        }
        showEditor = true
    }

    private func bootstrap() {
        weekStart = startOfWeek(containing: Date())
        selectedDay = calendar.startOfDay(for: Date())
        reload()
    }

    private func reload() {
        do {
            schedule = try database.schedules.ensureDefaultSchedule()
            let weekOcc = try database.schedules.occurrences(weekStarting: weekStart, calendar: calendar)
            var counts: [Date: Int] = [:]
            for occ in weekOcc {
                let displayDay = calendar.startOfDay(for: occ.start)
                counts[displayDay, default: 0] += 1
            }
            weekDayCounts = counts
            reloadDay()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadDay() {
        do {
            dayOccurrences = try database.schedules.occurrences(forDay: selectedDay, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shiftWeek(by weeks: Int) {
        guard let next = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) else { return }
        weekStart = calendar.startOfDay(for: next)
    }

    private func clampSelectedDayToWeek() {
        let days = daysInWeek
        guard let first = days.first, let last = days.last else { return }
        if selectedDay < first || selectedDay > last {
            let offset = calendar.dateComponents([.day], from: first, to: selectedDay).day ?? 0
            let clampedOffset = min(max(offset, 0), 6)
            selectedDay = calendar.date(byAdding: .day, value: clampedOffset, to: first) ?? first
        }
    }

    private func startOfWeek(containing date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let firstWeekday = calendar.firstWeekday
        let diff = (weekday - firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -diff, to: day) ?? day
    }
}
