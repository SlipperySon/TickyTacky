import SwiftUI

/// Applies `.navigationTitle` only when embedded as a top-level screen.
struct OptionalNavigationTitle: ViewModifier {
    var title: String
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.navigationTitle(title)
        } else {
            content
        }
    }
}
