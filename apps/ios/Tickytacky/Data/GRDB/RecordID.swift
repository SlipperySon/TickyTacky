import Foundation

/// Stable lowercase UUID strings for local + Supabase PKs.
/// Apple `UUID().uuidString` is uppercase; PostgREST returns lowercase — SQLite TEXT PKs are case-sensitive.
enum RecordID {
    static func make() -> String {
        UUID().uuidString.lowercased()
    }

    static func normalize(_ id: String) -> String {
        id.lowercased()
    }
}
