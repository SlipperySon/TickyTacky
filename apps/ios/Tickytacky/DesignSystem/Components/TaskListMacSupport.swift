import SwiftUI

extension View {
    /// Enables ⌫ / Delete to soft-delete the current list selection on Mac.
    @ViewBuilder
    func onTaskListDeleteCommand(
        selection: Set<String>,
        perform: @escaping (Set<String>) -> Void
    ) -> some View {
        #if os(macOS)
        onDeleteCommand {
            guard !selection.isEmpty else { return }
            perform(selection)
        }
        #else
        self
        #endif
    }
}
