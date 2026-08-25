import Foundation

/// Grocery list / item detection from names and titles (no list-type column).
enum GroceryMode {
    /// List becomes a grocery checklist when the name mentions grocery/groceries.
    static func isGroceryListName(_ name: String) -> Bool {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return folded.contains("grocery") || folded.contains("groceries")
    }

    /// Task title that mentions grocery — nudge toward a grocery list (not auto-convert).
    static func titleSuggestsGrocery(_ title: String) -> Bool {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        // Word-ish match so "non-grocery errand" still matches; avoid tiny false friends later if needed.
        return folded.contains("grocery") || folded.contains("groceries")
    }

    /// Finds an existing grocery list, or creates "Groceries".
    @discardableResult
    static func ensureGroceryList(database: AppDatabase) throws -> TaskListRecord {
        let lists = try ListService(database: database).fetchAll()
        if let existing = lists.first(where: { !$0.isInbox && isGroceryListName($0.name) }) {
            return existing
        }
        return try ListService(database: database).create(
            name: "Groceries",
            color: PastelSwatch.mist.rawValue,
            icon: "cart"
        )
    }

    /// Split a multi-line paste into grocery item titles.
    static func splitItemLines(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
