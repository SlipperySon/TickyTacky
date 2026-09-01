import SwiftUI

/// Floating sage quick-add control (toolbar / FAB-ish). Scales with Dynamic Type.
struct QuickAddButton: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    @ScaledMetric(relativeTo: .title2) private var side: CGFloat = 48

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.surfaceInk)
                .frame(width: side, height: side)
                .background(theme.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
        .shadow(color: theme.ink.opacity(0.12), radius: 6, y: 3)
    }
}
