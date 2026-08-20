import SwiftUI

/// Classic Notebook palette from DESIGN.md (locked MVP theme).
struct NotebookTokens: ThemeTokens {
    // Light
    let canvas = Color(hex: 0xF3EBDD)
    let canvasRuled = Color(hex: 0xE5DCCE)
    let surface = Color(hex: 0xFBF6EC)
    let surfaceInk = Color(hex: 0xFFFCF6)
    let ink = Color(hex: 0x2A2622)
    let inkMuted = Color(hex: 0x7A7268)
    let inkFaint = Color(hex: 0xA39A8E)
    let rule = Color(hex: 0xD4CBBA)
    let ruleNotebook = Color(hex: 0xC5D4E0)
    let accent = Color(hex: 0x7FAF98)
    let accentPressed = Color(hex: 0x6B9A84)
    let accentSoft = Color(hex: 0xE2F0E8)
    let accentSecondary = Color(hex: 0x8BB4C9)
    let accentSecondarySoft = Color(hex: 0xE0EEF5)
    let todayMark = Color(hex: 0x8BB4C9)
    let danger = Color(hex: 0xC46B5D)
    let overdue = Color(hex: 0xC47A6C)
    let warning = Color(hex: 0xD4B56A)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
