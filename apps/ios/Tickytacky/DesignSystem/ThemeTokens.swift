import SwiftUI

/// Token API for swappable themes later. MVP always resolves to Notebook.
/// Source of truth: DESIGN.md → NotebookTokens.
protocol ThemeTokens {
    var canvas: Color { get }
    var canvasRuled: Color { get }
    var surface: Color { get }
    var surfaceInk: Color { get }
    var ink: Color { get }
    var inkMuted: Color { get }
    var inkFaint: Color { get }
    var rule: Color { get }
    var ruleNotebook: Color { get }
    var accent: Color { get }
    var accentPressed: Color { get }
    var accentSoft: Color { get }
    var accentSecondary: Color { get }
    var accentSecondarySoft: Color { get }
    var todayMark: Color { get }
    var danger: Color { get }
    var overdue: Color { get }
    var warning: Color { get }
}

enum Theme {
    static var current: ThemeTokens { NotebookTokens() }
}
