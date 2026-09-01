import SwiftUI

/// Token API for swappable palettes.
/// Source of truth: DESIGN.md.
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

/// Dark Mode palette choice. Light Mode is always Classic Notebook.
enum DarkThemeID: String, CaseIterable, Identifiable {
    case notebook
    case morocco
    case clothbound

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notebook: "Notebook"
        case .morocco: "Morocco"
        case .clothbound: "Clothbound"
        }
    }

    var footer: String {
        switch self {
        case .notebook:
            "Dimmed paper and sage. Used when the system is in Dark Mode."
        case .morocco:
            "Leather-bound cocoa, parchment ink, kraft chrome. Used when the system is in Dark Mode."
        case .clothbound:
            "Charcoal cloth, parchment ink, kraft gilt. Used when the system is in Dark Mode."
        }
    }
}

/// Resolved colors for the current appearance. Passed through the environment so chrome updates live.
struct ThemePalette: ThemeTokens, Equatable {
    let canvas: Color
    let canvasRuled: Color
    let surface: Color
    let surfaceInk: Color
    let ink: Color
    let inkMuted: Color
    let inkFaint: Color
    let rule: Color
    let ruleNotebook: Color
    let accent: Color
    let accentPressed: Color
    let accentSoft: Color
    let accentSecondary: Color
    let accentSecondarySoft: Color
    let todayMark: Color
    let danger: Color
    let overdue: Color
    let warning: Color

    init(_ tokens: some ThemeTokens) {
        canvas = tokens.canvas
        canvasRuled = tokens.canvasRuled
        surface = tokens.surface
        surfaceInk = tokens.surfaceInk
        ink = tokens.ink
        inkMuted = tokens.inkMuted
        inkFaint = tokens.inkFaint
        rule = tokens.rule
        ruleNotebook = tokens.ruleNotebook
        accent = tokens.accent
        accentPressed = tokens.accentPressed
        accentSoft = tokens.accentSoft
        accentSecondary = tokens.accentSecondary
        accentSecondarySoft = tokens.accentSecondarySoft
        todayMark = tokens.todayMark
        danger = tokens.danger
        overdue = tokens.overdue
        warning = tokens.warning
    }

    static func resolve(colorScheme: ColorScheme, darkTheme: DarkThemeID) -> ThemePalette {
        switch colorScheme {
        case .light:
            ThemePalette(NotebookTokens())
        case .dark:
            switch darkTheme {
            case .notebook: ThemePalette(NotebookDarkTokens())
            case .morocco: ThemePalette(MoroccoTokens())
            case .clothbound: ThemePalette(ClothboundTokens())
            }
        @unknown default:
            ThemePalette(NotebookTokens())
        }
    }
}

@Observable
@MainActor
final class ThemeStore {
    static let shared = ThemeStore()

    private static let darkThemeKey = "appearance.darkThemeID"

    var darkThemeID: DarkThemeID {
        didSet {
            UserDefaults.standard.set(darkThemeID.rawValue, forKey: Self.darkThemeKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.darkThemeKey) ?? ""
        darkThemeID = DarkThemeID(rawValue: raw) ?? .notebook
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemePalette(NotebookTokens())
}

extension EnvironmentValues {
    var theme: ThemePalette {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeRootModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var store: ThemeStore

    func body(content: Content) -> some View {
        let palette = ThemePalette.resolve(colorScheme: colorScheme, darkTheme: store.darkThemeID)
        content
            .environment(\.theme, palette)
            .tint(palette.accent)
    }
}

extension View {
    /// Form / grouped-list row wash on the active canvas (avoids system white cells).
    func notebookGroupedRowBackground() -> some View {
        modifier(NotebookGroupedRowBackground())
    }

    func tickytackyTheme(_ store: ThemeStore) -> some View {
        modifier(ThemeRootModifier(store: store))
    }
}

private struct NotebookGroupedRowBackground: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.listRowBackground(theme.surface)
    }
}
