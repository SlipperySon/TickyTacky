import SwiftUI

/// Task priority stored as int 0…4 in SQLite.
enum Priority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case urgent = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    /// Dot color from DESIGN.md — always pair with `title` for accessibility.
    var dotColor: Color {
        switch self {
        case .none: Color(hex: 0xA39A8E)
        case .low: Color(hex: 0x8BB4C9)
        case .medium: Color(hex: 0xD4B56A)
        case .high: Color(hex: 0xE0A37A)
        case .urgent: Color(hex: 0xC47A6C)
        }
    }
}
