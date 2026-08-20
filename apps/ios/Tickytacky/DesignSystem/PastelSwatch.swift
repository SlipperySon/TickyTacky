import SwiftUI

/// Curated pastel sticker palette from DESIGN.md (list / tag / timetable).
enum PastelSwatch: String, CaseIterable, Identifiable, Sendable {
    case sage, sky, lilac, blush, butter, mist, slate, kraft

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sage: "Sage"
        case .sky: "Sky"
        case .lilac: "Lilac"
        case .blush: "Blush"
        case .butter: "Butter"
        case .mist: "Mist"
        case .slate: "Slate"
        case .kraft: "Kraft"
        }
    }

    var fill: Color {
        switch self {
        case .sage: Color(hex: 0x7FAF98)
        case .sky: Color(hex: 0x8BB4C9)
        case .lilac: Color(hex: 0xB7A7C9)
        case .blush: Color(hex: 0xE2B6AE)
        case .butter: Color(hex: 0xE5D39A)
        case .mist: Color(hex: 0xB8C9C1)
        case .slate: Color(hex: 0xA3AAB3)
        case .kraft: Color(hex: 0xC4A882)
        }
    }

    var onFill: Color {
        switch self {
        case .sage: Color(hex: 0x1F2E28)
        case .sky: Color(hex: 0x1E2C34)
        case .lilac: Color(hex: 0x2A2433)
        case .blush: Color(hex: 0x3A2826)
        case .butter: Color(hex: 0x3A3420)
        case .mist: Color(hex: 0x24302C)
        case .slate: Color(hex: 0x24262A)
        case .kraft: Color(hex: 0x2E261C)
        }
    }

    /// Timetable sticker fill at ~88% opacity on paper.
    var stickerFill: Color { fill.opacity(0.88) }

    static func resolve(_ raw: String?) -> PastelSwatch {
        PastelSwatch(rawValue: raw ?? "") ?? .sage
    }
}
