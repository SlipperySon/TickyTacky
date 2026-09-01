import SwiftUI

/// Compact tag label using theme tokens (no card chrome).
struct TagChip: View {
    let name: String
    var isSelected: Bool = false
    @Environment(\.theme) private var theme

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .foregroundStyle(isSelected ? theme.surfaceInk : theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? theme.accent : theme.accentSoft)
            .clipShape(Capsule())
            .accessibilityLabel("Tag \(name)")
    }
}
