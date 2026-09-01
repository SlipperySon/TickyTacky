import Foundation
import Security

/// Minimal Keychain helper for calendar bridge OAuth tokens.
enum CalendarBridgeKeychain {
    enum Key: String {
        case googleAccessToken = "calendarBridge.google.accessToken"
        case googleRefreshToken = "calendarBridge.google.refreshToken"
        case googleTokenExpiry = "calendarBridge.google.tokenExpiry"
    }

    static func setString(_ value: String?, for key: Key) {
        guard let value, !value.isEmpty else {
            delete(key)
            return
        }
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "app.tickytacky.calendarBridge",
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func string(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "app.tickytacky.calendarBridge",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func setDate(_ date: Date?, for key: Key) {
        guard let date else {
            delete(key)
            return
        }
        setString(String(date.timeIntervalSince1970), for: key)
    }

    static func date(for key: Key) -> Date? {
        guard let raw = string(for: key), let interval = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: "app.tickytacky.calendarBridge",
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearGoogleTokens() {
        delete(.googleAccessToken)
        delete(.googleRefreshToken)
        delete(.googleTokenExpiry)
    }
}
