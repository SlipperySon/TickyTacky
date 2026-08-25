import SwiftUI

/// Phone home row: Today + Calendar | center + | Focus + Settings.
/// Laid out as a sibling below main content (not an overlay).
struct CenterPlusTabBar: View {
    @Binding var selectedTab: Int
    var onPlus: () -> Void

    private let theme = Theme.current
    private let plusSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(theme.rule.opacity(0.65))
                .frame(height: 1)
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 0) {
                tabButton(index: 0, title: "Today", systemImage: "sun.max")
                tabButton(index: 1, title: "Calendar", systemImage: "calendar")

                Spacer(minLength: 0)

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.surfaceInk)
                        .frame(width: plusSize, height: plusSize)
                        .background(theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add task or schedule")

                Spacer(minLength: 0)

                tabButton(index: 2, title: "Focus", systemImage: "timer")
                tabButton(index: 3, title: "Settings", systemImage: "gearshape")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        // Fill the home-indicator band only; this view’s layout height stays
        // in the VStack below content so Today never scrolls underneath it.
        .background {
            theme.surface
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    private func tabButton(index: Int, title: String, systemImage: String) -> some View {
        let selected = selectedTab == index
        return Button {
            selectedTab = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                Text(title)
                    .font(.caption2.weight(selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? theme.accent : theme.inkMuted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: plusSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
