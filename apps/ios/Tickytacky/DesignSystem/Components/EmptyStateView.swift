import SwiftUI

/// SF Rounded empty-state title + muted supporting line.
struct EmptyStateView: View {
    var title: String
    var message: String
    private let theme = Theme.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(theme.ink)
            Text(message)
                .font(.body)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
