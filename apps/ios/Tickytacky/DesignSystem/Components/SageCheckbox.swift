import SwiftUI

/// Rounded-square checkbox with sage fill when done (DESIGN.md). Scales with Dynamic Type.
struct SageCheckbox: View {
    var isOn: Bool
    /// Included in VoiceOver label when set (e.g. task/subtask title).
    var title: String? = nil
    /// When true, hide from VoiceOver (parent row provides the combined label + action).
    var accessibilityHidden: Bool = false
    var action: () -> Void
    private let theme = Theme.current

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 18

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isOn ? theme.accent : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(isOn ? theme.accent : theme.inkMuted, lineWidth: 1.5)
                }
                .overlay {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.surfaceInk)
                    }
                }
                .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(accessibilityHidden)
    }

    private var accessibilityLabelText: String {
        if let title, !title.isEmpty {
            return isOn ? "\(title), completed" : "Mark \(title) complete"
        }
        return isOn ? "Completed" : "Not completed"
    }
}
