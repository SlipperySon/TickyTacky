import SwiftUI

/// Day Gantt: hours down the side, timetable blocks as pastel bars (Notebook vibe).
struct DayGanttView: View {
    @Environment(\.appDatabase) private var database
    @Environment(\.calendar) private var calendar

    @State private var selectedDay: Date = Date()
    @State private var schedule: ScheduleRecord?
    @State private var occurrences: [ScheduleOccurrence] = []
    @State private var selectedOccurrence: ScheduleOccurrence?
    @State private var showEditor = false
    @State private var errorMessage: String?

    @Environment(\.theme) private var theme
    private let hourHeight: CGFloat = 52
    private let gutterWidth: CGFloat = 52
    private let defaultStartHour = 6
    private let defaultEndHour = 22

    private static let dayTitleFormatter = AppCalendar.dayTitle
    private static let hourFormatter = AppCalendar.timeShort

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                dayHeader
                Divider().overlay(theme.rule)
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(theme.danger)
                        .padding(20)
                    Spacer()
                } else {
                    ganttScroll
                }
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
        .onChange(of: selectedDay) { _, _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .tickytackyContentDidChange)) { _ in
            reload()
        }
    }

    private var dayHeader: some View {
        HStack {
            Button {
                shiftDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 2) {
                Text(Self.dayTitleFormatter.string(from: selectedDay))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(theme.ink)
                if !calendar.isDateInToday(selectedDay) {
                    Button("Today") {
                        selectedDay = calendar.startOfDay(for: Date())
                    }
                    .font(.caption.weight(.medium))
                    .tint(theme.accentSecondary)
                }
            }
            .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                shiftDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next day")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .foregroundStyle(theme.ink)
    }

    @ViewBuilder
    private var ganttScroll: some View {
        if occurrences.isEmpty {
            ScrollView {
                EmptyStateView(
                    title: "Nothing scheduled",
                    message: "Add a timetable block — it’ll show as a bar on this day."
                )
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            let range = visibleHourRange
            let hours = Array(range.start..<range.end)
            let totalHeight = CGFloat(hours.count) * hourHeight
            let lanes = assignLanes(occurrences)

            ScrollView {
                GeometryReader { geo in
                    let trackWidth = max(80, geo.size.width - gutterWidth - 8)
                    ZStack(alignment: .topLeading) {
                        hourGrid(hours: hours, height: totalHeight)

                        ForEach(occurrences) { occurrence in
                            let lane = lanes[occurrence.id] ?? 0
                            let laneCount = max(1, (lanes.values.max() ?? 0) + 1)
                            bar(
                                for: occurrence,
                                rangeStart: range.start,
                                lane: lane,
                                laneCount: laneCount,
                                trackWidth: trackWidth
                            )
                        }
                    }
                }
                .frame(height: max(totalHeight, 200))
                .padding(.trailing, 8)
            }
        }
    }

    private func hourGrid(hours: [Int], height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(hours, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 0) {
                        Text(hourLabel(hour))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.inkFaint)
                            .frame(width: gutterWidth, alignment: .trailing)
                            .padding(.trailing, 8)
                        Rectangle()
                            .fill(theme.ruleNotebook.opacity(0.55))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .frame(height: hourHeight, alignment: .top)
                }
            }
            .frame(height: height)

            if calendar.isDateInToday(selectedDay),
               let y = nowY(rangeStart: hours.first ?? defaultStartHour),
               y >= 0, y <= height {
                HStack(spacing: 0) {
                    Color.clear.frame(width: gutterWidth)
                    Rectangle()
                        .fill(theme.todayMark)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
                .offset(y: y)
                .accessibilityLabel("Current time")
            }
        }
    }

    private func bar(
        for occurrence: ScheduleOccurrence,
        rangeStart: Int,
        lane: Int,
        laneCount: Int,
        trackWidth: CGFloat
    ) -> some View {
        let swatch = PastelSwatch.resolve(occurrence.color)
        let layout = barLayout(occurrence: occurrence, rangeStart: rangeStart)
        let laneWidth = trackWidth / CGFloat(laneCount)
        let x = gutterWidth + CGFloat(lane) * laneWidth + 4
        let width = max(40, laneWidth - 8)

        return Button {
            selectedOccurrence = occurrence
        } label: {
            Text(occurrence.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(swatch.onFill)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: width, height: max(22, layout.height), alignment: .topLeading)
                .background(swatch.stickerFill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(swatch.fill.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .offset(x: x, y: layout.y)
        .accessibilityLabel("\(occurrence.title), \(timeLabel(occurrence.start)) to \(timeLabel(occurrence.end))")
        .accessibilityHint("Opens occurrence actions")
    }

    private func barLayout(occurrence: ScheduleOccurrence, rangeStart: Int) -> (y: CGFloat, height: CGFloat) {
        let startMinutes = minutesFromMidnight(occurrence.start)
        let endMinutes = max(startMinutes + 15, minutesFromMidnight(occurrence.end))
        let rangeStartMinutes = rangeStart * 60
        let y = CGFloat(startMinutes - rangeStartMinutes) / 60 * hourHeight
        let height = CGFloat(endMinutes - startMinutes) / 60 * hourHeight
        return (max(0, y), max(22, height - 2))
    }

    private var visibleHourRange: (start: Int, end: Int) {
        var start = defaultStartHour
        var end = defaultEndHour
        for occ in occurrences {
            let sh = calendar.component(.hour, from: occ.start)
            var eh = calendar.component(.hour, from: occ.end)
            let em = calendar.component(.minute, from: occ.end)
            if em > 0 { eh += 1 }
            start = min(start, max(0, sh))
            end = max(end, min(24, max(eh + 1, sh + 1)))
        }
        if start >= end { return (defaultStartHour, defaultEndHour) }
        return (start, end)
    }

    private func assignLanes(_ items: [ScheduleOccurrence]) -> [String: Int] {
        var laneEnds: [Int] = []
        var result: [String: Int] = [:]
        let sorted = items.sorted { $0.start < $1.start }
        for item in sorted {
            let start = minutesFromMidnight(item.start)
            if let lane = laneEnds.firstIndex(where: { $0 <= start }) {
                result[item.id] = lane
                laneEnds[lane] = minutesFromMidnight(item.end)
            } else {
                result[item.id] = laneEnds.count
                laneEnds.append(minutesFromMidnight(item.end))
            }
        }
        return result
    }

    private func nowY(rangeStart: Int) -> CGFloat? {
        let minutes = minutesFromMidnight(Date())
        return CGFloat(minutes - rangeStart * 60) / 60 * hourHeight
    }

    private func minutesFromMidnight(_ date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = calendar.date(from: comps) ?? Date()
        return Self.hourFormatter.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func bootstrap() {
        selectedDay = calendar.startOfDay(for: Date())
        reload()
    }

    private func reload() {
        do {
            schedule = try database.schedules.ensureDefaultSchedule()
            occurrences = try database.schedules.occurrences(forDay: selectedDay, calendar: calendar)
                .sorted { $0.start < $1.start }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func shiftDay(by days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: selectedDay) else { return }
        selectedDay = calendar.startOfDay(for: next)
    }

    private func openEditor() {
        if schedule == nil { reload() }
        showEditor = true
    }
}
