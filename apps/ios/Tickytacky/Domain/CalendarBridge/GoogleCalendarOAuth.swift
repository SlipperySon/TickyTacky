import AuthenticationServices
import CryptoKit
import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Google OAuth (PKCE) via `ASWebAuthenticationSession` — no GoogleSignIn SDK.
@MainActor
final class GoogleCalendarOAuth: NSObject {
    static let shared = GoogleCalendarOAuth()

    static let calendarScope = "https://www.googleapis.com/auth/calendar"
    private static let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

    private var presentationContext: AuthPresentationContext?
    private var currentSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    var clientID: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CALENDAR_CLIENT_ID") as? String
        guard let raw, !raw.isEmpty, !raw.hasPrefix("YOUR_"), raw.contains(".apps.googleusercontent.com")
        else { return nil }
        return raw
    }

    var reversedClientID: String? {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CALENDAR_REVERSED_CLIENT_ID") as? String,
           !raw.isEmpty, !raw.hasPrefix("YOUR_"), raw.hasPrefix("com.googleusercontent.apps.") {
            return raw
        }
        guard let clientID else { return nil }
        // 123-abc.apps.googleusercontent.com → com.googleusercontent.apps.123-abc
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        guard !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix)"
    }

    var isConfigured: Bool { clientID != nil }

    var isSignedIn: Bool {
        CalendarBridgeKeychain.string(for: .googleRefreshToken) != nil
            || CalendarBridgeKeychain.string(for: .googleAccessToken) != nil
    }

    func signIn() async throws {
        guard let clientID, let reversed = reversedClientID else {
            throw CalendarBridgeProviderError.missingClientID
        }
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.makeCodeChallenge(verifier: verifier)
        let redirectURI = "\(reversed):/oauth2redirect/google"

        var comps = URLComponents(url: Self.authURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.calendarScope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let url = comps.url else {
            throw GoogleCalendarOAuthError.invalidAuthURL
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let context = AuthPresentationContext()
            self.presentationContext = context
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: reversed
            ) { callback, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callback else {
                    continuation.resume(throwing: GoogleCalendarOAuthError.missingCallback)
                    return
                }
                continuation.resume(returning: callback)
            }
            session.presentationContextProvider = context
            session.prefersEphemeralWebBrowserSession = false
            self.currentSession = session
            if !session.start() {
                continuation.resume(throwing: GoogleCalendarOAuthError.sessionStartFailed)
            }
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
        else {
            throw GoogleCalendarOAuthError.missingAuthCode
        }

        try await exchangeCode(
            code,
            clientID: clientID,
            redirectURI: redirectURI,
            verifier: verifier
        )
    }

    func signOut() {
        CalendarBridgeKeychain.clearGoogleTokens()
        currentSession?.cancel()
        currentSession = nil
    }

    /// Returns a valid access token, refreshing when needed.
    func validAccessToken() async throws -> String {
        if let token = CalendarBridgeKeychain.string(for: .googleAccessToken),
           let expiry = CalendarBridgeKeychain.date(for: .googleTokenExpiry),
           expiry > Date().addingTimeInterval(60) {
            return token
        }
        return try await refreshAccessToken()
    }

    // MARK: - Token exchange

    private func exchangeCode(
        _ code: String,
        clientID: String,
        redirectURI: String,
        verifier: String
    ) async throws {
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ]
        request.httpBody = Self.formEncode(body).data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfNeeded(data: data, response: response)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        store(token)
    }

    private func refreshAccessToken() async throws -> String {
        guard let clientID else { throw CalendarBridgeProviderError.missingClientID }
        guard let refresh = CalendarBridgeKeychain.string(for: .googleRefreshToken) else {
            throw GoogleCalendarOAuthError.notSignedIn
        }
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ]
        request.httpBody = Self.formEncode(body).data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.throwIfNeeded(data: data, response: response)
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        store(token, preservingRefreshToken: refresh)
        guard let access = CalendarBridgeKeychain.string(for: .googleAccessToken) else {
            throw GoogleCalendarOAuthError.notSignedIn
        }
        return access
    }

    private func store(_ token: TokenResponse, preservingRefreshToken: String? = nil) {
        CalendarBridgeKeychain.setString(token.access_token, for: .googleAccessToken)
        if let refresh = token.refresh_token ?? preservingRefreshToken {
            CalendarBridgeKeychain.setString(refresh, for: .googleRefreshToken)
        }
        let expiry = Date().addingTimeInterval(TimeInterval(token.expires_in ?? 3600))
        CalendarBridgeKeychain.setDate(expiry, for: .googleTokenExpiry)
    }

    // MARK: - PKCE helpers

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func makeCodeChallenge(verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        fields
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    private static func throwIfNeeded(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GoogleCalendarOAuthError.httpError(http.statusCode, body)
        }
    }

    private struct TokenResponse: Decodable {
        var access_token: String
        var expires_in: Int?
        var refresh_token: String?
        var token_type: String?
        var scope: String?
    }
}

enum GoogleCalendarOAuthError: LocalizedError {
    case invalidAuthURL
    case missingCallback
    case sessionStartFailed
    case missingAuthCode
    case notSignedIn
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidAuthURL: "Could not build Google sign-in URL."
        case .missingCallback: "Google sign-in returned no callback."
        case .sessionStartFailed: "Could not start Google sign-in."
        case .missingAuthCode: "Google sign-in did not return an auth code."
        case .notSignedIn: "Sign in with Google to sync Calendar."
        case .httpError(let code, let body):
            "Google OAuth failed (\(code)): \(body)"
        }
    }
}

private final class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return key
        }
        if let first = scenes.flatMap(\.windows).first {
            return first
        }
        return ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
