import SwiftUI

/// Phone home row: Today + Calendar | center + | Focus + Settings.
/// Laid out as a sibling below main content (not an overlay).
struct CenterPlusTabBar: View {
    @Binding var selectedTab: Int
    var onPlus: () -> Void

    @Environment(\.theme) private var theme
    private let iconPointSize: CGFloat = 20
    private let plusCircleSize: CGFloat = 55
    /// Shared band so tab icons and the larger + stay vertically centred together.
    private var iconBandHeight: CGFloat { plusCircleSize }
    private let labelHeight: CGFloat = 14
    private let columnSpacing: CGFloat = 0

    private let tabs: [(title: String, systemImage: String)] = [
        ("Today", "sun.max"),
        ("Calendar", "calendar"),
        ("Focus", "timer"),
        ("Settings", "gearshape"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(theme.rule.opacity(0.65))
                .frame(height: 1)
                .allowsHitTesting(false)

            GeometryReader { geo in
                let slotWidth = geo.size.width / 5
                HStack(alignment: .center, spacing: columnSpacing) {
                    tabSlot(index: 0, width: slotWidth)
                    tabSlot(index: 1, width: slotWidth)
                    plusSlot(width: slotWidth)
                    tabSlot(index: 2, width: slotWidth)
                    tabSlot(index: 3, width: slotWidth)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
            .frame(height: iconBandHeight + 3 + labelHeight)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        .background {
            theme.surface
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    private func tabSlot(index: Int, width: CGFloat) -> some View {
        let tab = tabs[index]
        let selected = selectedTab == index
        return Button {
            selectedTab = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: iconPointSize, weight: selected ? .semibold : .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: iconBandHeight, height: iconBandHeight)

                Text(tab.title)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: labelHeight)
            }
            .foregroundStyle(selected ? theme.accent : theme.inkMuted)
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func plusSlot(width: CGFloat) -> some View {
        Button(action: onPlus) {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(theme.surfaceInk)
                    .frame(width: plusCircleSize, height: plusCircleSize)
                    .background(theme.accent, in: Circle())
                    .frame(width: iconBandHeight, height: iconBandHeight)

                // Same label band as tabs so the + stays optically centred in the row.
                Color.clear
                    .frame(height: labelHeight)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task or schedule")
    }
}
