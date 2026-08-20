import SwiftUI

/// Priority dot + VoiceOver label (color is never the sole signal).
struct PriorityIndicator: View {
    var priority: Priority

    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 8

    var body: some View {
        Circle()
            .fill(priority.dotColor)
            .frame(width: side, height: side)
            .accessibilityLabel("Priority \(priority.title)")
            .opacity(priority == .none ? 0.55 : 1)
    }
}
