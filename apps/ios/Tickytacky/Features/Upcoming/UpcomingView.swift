import SwiftUI

enum UpcomingPane: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }

    private static let storageKey = "calendar.selectedPane"

    static var stored: UpcomingPane {
        get {
            guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .day }
            if raw == "agenda" { return .week }
            return UpcomingPane(rawValue: raw) ?? .day
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

/// Calendar tab: Day Gantt, weekly timetable, or month grid (AU week starts Monday).
struct UpcomingView: View {
    private let theme = Theme.current

    var embedsNavigationStack: Bool = true

    @State private var pane: UpcomingPane = .stored

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
        VStack(spacing: 0) {
            Picker("Calendar", selection: $pane) {
                ForEach(UpcomingPane.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.canvas)

            Group {
                switch pane {
                case .day:
                    DayGanttView()
                case .week:
                    TimetableView(embedsNavigationStack: false, showsNavigationTitle: false)
                case .month:
                    MonthCalendarView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.canvas.ignoresSafeArea())
        .environment(\.calendar, AppCalendar.gregorian)
        .environment(\.locale, AppCalendar.locale)
        .navigationTitle("Calendar")
        .task { pane = .stored }
        .onChange(of: pane) { _, newValue in
            UpcomingPane.stored = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .tickytackySelectUpcomingPane)) { note in
            if let raw = note.object as? String, let next = UpcomingPane(rawValue: raw) {
                pane = next
            } else if let next = note.object as? UpcomingPane {
                pane = next
            } else if let raw = note.object as? String, raw == "agenda" {
                pane = .week
            }
        }
    }
}

extension Notification.Name {
    static let tickytackySelectUpcomingPane = Notification.Name("tickytackySelectUpcomingPane")
}
