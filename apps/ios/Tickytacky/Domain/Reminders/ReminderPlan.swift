import Foundation

/// Pure planned local notification (no UserNotifications dependency).
struct ReminderPlan: Equatable, Sendable, Identifiable {
    var id: String { identifier }

    /// Stable idempotent request identifier.
    var identifier: String
    var fireDate: Date
    var title: String
    var body: String
    var userInfo: [String: String]
}

enum ReminderDeepLinkKind: String, Sendable {
    case task
    case occurrence
}

enum ReminderUserInfoKey {
    static let kind = "kind"
    static let taskId = "taskId"
    static let blockId = "blockId"
    static let originalStart = "originalStart"
}
