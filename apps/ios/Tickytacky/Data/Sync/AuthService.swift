import CryptoKit
import AuthenticationServices
import Foundation
import Observation
import Supabase

/// Sign in with Apple → Supabase session. Local CRUD works without a session.
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var session: Session?
    private(set) var isLoading = false
    private(set) var lastError: String?

    var isSignedIn: Bool { session != nil }
    var userId: String? { session?.user.id.uuidString.lowercased() }
    var userEmail: String? { session?.user.email }

    private var authListenerTask: Task<Void, Never>?
    /// Raw nonce for the in-flight Apple Sign In (hashed form sent to Apple).
    private var pendingAppleNonce: String?

    private init() {
        guard SupabaseClientConfig.client != nil else { return }
        authListenerTask = Task { await listenForAuthChanges() }
        Task { await refreshSession() }
    }

    func refreshSession() async {
        guard let client = SupabaseClientConfig.client else {
            session = nil
            return
        }
        do {
            session = try await client.auth.session
            lastError = nil
        } catch {
            session = nil
        }
    }

    /// Configures the Apple request with scopes + SHA-256 nonce (Supabase requires nonce).
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        pendingAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256Hex(nonce)
    }

    /// Exchange an Apple identity token for a Supabase session.
    func signInWithApple(idToken: String, nonce: String?, fullName: PersonNameComponents? = nil) async {
        guard let client = SupabaseClientConfig.client else {
            lastError = "Supabase is not configured. Add URL and anon key in Secrets.xcconfig."
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let result = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            session = result
            pendingAppleNonce = nil
            if let fullName {
                let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                let joined = parts.joined(separator: " ")
                if !joined.isEmpty {
                    _ = try? await client.auth.update(
                        user: UserAttributes(data: ["full_name": .string(joined)])
                    )
                }
            }
        } catch {
            lastError = error.localizedDescription
            session = nil
        }
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            lastError = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastError = AuthError.invalidCredential.localizedDescription
                return
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                lastError = AuthError.missingIdentityToken.localizedDescription
                return
            }
            let nonce = pendingAppleNonce
            await signInWithApple(idToken: idToken, nonce: nonce, fullName: credential.fullName)
            if isSignedIn {
                SyncEngine.shared.syncIfPossible()
            }
        }
    }

    func signOut() async {
        guard let client = SupabaseClientConfig.client else {
            session = nil
            clearLocalUserCache()
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try await client.auth.signOut()
            session = nil
            clearLocalUserCache()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Wipe local domain data so a shared device cannot browse the previous account offline.
    private func clearLocalUserCache() {
        try? AppDatabase.shared.resetUserData()
        SyncEngine.shared.refreshDirtyCount()
        NotificationCenter.default.post(name: .tickytackyContentDidChange, object: nil)
    }

    private func listenForAuthChanges() async {
        guard let client = SupabaseClientConfig.client else { return }
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                self.session = session
                if session != nil {
                    SyncEngine.shared.syncIfPossible()
                }
            case .signedOut:
                self.session = nil
            default:
                break
            }
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            precondition(status == errSecSuccess, "Unable to generate nonce")
            result.append(charset[Int(byte) % charset.count])
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case missingIdentityToken
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Invalid Apple credential."
        case .missingIdentityToken: "Apple did not return an identity token."
        case .notConfigured: "Supabase is not configured."
        }
    }
}
