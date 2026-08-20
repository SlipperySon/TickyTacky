import Foundation
import Supabase

/// Reads Supabase URL/anon key from Info.plist (injected via xcconfig).
/// When configured, exposes a shared `SupabaseClient` for Auth + SyncEngine.
struct SupabaseClientConfig: Sendable {
    var urlString: String
    var anonKey: String

    var isConfigured: Bool {
        !urlString.isEmpty
            && !anonKey.isEmpty
            && urlString != "YOUR_SUPABASE_URL"
            && anonKey != "YOUR_SUPABASE_ANON_KEY"
            && URL(string: urlString) != nil
    }

    static let shared: SupabaseClientConfig = {
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
        return SupabaseClientConfig(urlString: url, anonKey: key)
    }()

    /// Live client when secrets are set; otherwise nil (offline-only local CRUD).
    static let client: SupabaseClient? = {
        let config = shared
        guard config.isConfigured, let url = URL(string: config.urlString) else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()
}
