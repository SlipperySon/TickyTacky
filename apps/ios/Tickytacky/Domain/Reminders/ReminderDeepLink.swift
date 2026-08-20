import Foundation

/// Deep-link payload carried in notification `userInfo` / URL scheme.
enum ReminderDeepLink: Equatable, Sendable {
    case task(id: String)
    case occurrence(blockId: String, originalStart: Date)

    static let urlScheme = "tickytacky"

    static func parse(userInfo: [AnyHashable: Any]) -> ReminderDeepLink? {
        guard let kindRaw = userInfo[ReminderUserInfoKey.kind] as? String,
              let kind = ReminderDeepLinkKind(rawValue: kindRaw)
        else { return nil }
        switch kind {
        case .task:
            guard let id = userInfo[ReminderUserInfoKey.taskId] as? String, !id.isEmpty else { return nil }
            return .task(id: id)
        case .occurrence:
            guard let blockId = userInfo[ReminderUserInfoKey.blockId] as? String, !blockId.isEmpty,
                  let stamp = userInfo[ReminderUserInfoKey.originalStart] as? String,
                  let originalStart = ISO8601DateFormatter().date(from: stamp)
            else { return nil }
            return .occurrence(blockId: blockId, originalStart: originalStart)
        }
    }

    static func parse(url: URL) -> ReminderDeepLink? {
        guard url.scheme == urlScheme else { return nil }
        let host = url.host ?? ""
        let pathParts = url.path.split(separator: "/").map(String.init)
        switch host {
        case "task":
            let id = pathParts.first ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !id.isEmpty else { return nil }
            return .task(id: id)
        case "occurrence":
            let blockId = pathParts.first ?? ""
            guard !blockId.isEmpty else { return nil }
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let stamp = comps?.queryItems?.first(where: { $0.name == "originalStart" })?.value
            guard let stamp, let originalStart = ISO8601DateFormatter().date(from: stamp) else { return nil }
            return .occurrence(blockId: blockId, originalStart: originalStart)
        default:
            return nil
        }
    }

    var url: URL? {
        switch self {
        case .task(let id):
            return URL(string: "\(Self.urlScheme)://task/\(id)")
        case .occurrence(let blockId, let originalStart):
            var comps = URLComponents()
            comps.scheme = Self.urlScheme
            comps.host = "occurrence"
            comps.path = "/\(blockId)"
            comps.queryItems = [
                URLQueryItem(
                    name: "originalStart",
                    value: ISO8601DateFormatter().string(from: originalStart)
                )
            ]
            return comps.url
        }
    }
}

extension Notification.Name {
    static let tickytackyOpenReminderDeepLink = Notification.Name("tickytackyOpenReminderDeepLink")
}
