import SwiftUI

/// Full-bleed task row: sage checkbox, title, due, priority (no card chrome).
struct TaskRow: View {
    let task: TaskRecord
    var onToggleComplete: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SageCheckbox(
                isOn: task.isCompleted,
                title: task.title,
                accessibilityHidden: true,
                action: onToggleComplete
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? theme.inkFaint : theme.ink)
                    .strikethrough(task.isCompleted, color: theme.inkFaint)
                    .lineLimit(2)

                if let dueLabel = dueLabel {
                    Text(dueLabel)
                        .font(.caption)
                        .foregroundStyle(dueColor)
                }
            }

            Spacer(minLength: 8)

            if task.priorityValue != .none {
                PriorityIndicator(priority: task.priorityValue)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAction(named: Text("Toggle completion")) {
            onToggleComplete()
        }
    }

    private var dueLabel: String? {
        guard let due = task.dueDate else { return nil }
        var parts: [String] = []
        if due < DueDate.today() {
            parts.append("Overdue")
        }
        parts.append(AppCalendar.dayMonth.string(from: due))
        if task.hasDueTime, let hour = task.dueHour, let minute = task.dueMinute {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            if let time = AppCalendar.gregorian.date(from: comps) {
                parts.append(AppCalendar.timeShort.string(from: time))
            }
        }
        return parts.joined(separator: " · ")
    }

    private var dueColor: Color {
        guard let due = task.dueDate, !task.isCompleted else { return theme.inkMuted }
        if due < DueDate.today() { return theme.overdue }
        if DueDate.isSameDay(due, DueDate.today()) { return theme.todayMark }
        return theme.inkMuted
    }

    private var accessibilitySummary: String {
        var bits = [task.title]
        bits.append(task.isCompleted ? "completed" : "incomplete")
        if task.priorityValue != .none {
            bits.append("priority \(task.priorityValue.title)")
        }
        if let dueLabel { bits.append(dueLabel) }
        return bits.joined(separator: ", ")
    }
}
