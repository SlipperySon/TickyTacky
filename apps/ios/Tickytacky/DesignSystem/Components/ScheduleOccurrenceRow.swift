import SwiftUI

/// Pastel sticker row for a timetable occurrence (DESIGN.md r=5–6).
struct ScheduleOccurrenceRow: View {
    var occurrence: ScheduleOccurrence
    private let theme = Theme.current

    private var swatch: PastelSwatch { PastelSwatch.resolve(occurrence.color) }

    private static let timeFormatter = AppCalendar.timeShort

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.timeFormatter.string(from: occurrence.start))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.inkMuted)
                Text(Self.timeFormatter.string(from: occurrence.end))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.inkFaint)
            }
            .frame(minWidth: 52, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)

            HStack {
                Text(occurrence.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(swatch.onFill)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if occurrence.isExceptionApplied {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(swatch.onFill.opacity(0.7))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(swatch.stickerFill)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [
            occurrence.title,
            "\(Self.timeFormatter.string(from: occurrence.start)) to \(Self.timeFormatter.string(from: occurrence.end))"
        ]
        if occurrence.isExceptionApplied {
            parts.append("rescheduled")
        }
        return parts.joined(separator: ", ")
    }
}
