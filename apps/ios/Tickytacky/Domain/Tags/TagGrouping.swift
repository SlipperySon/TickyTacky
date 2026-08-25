import Foundation

/// Soft list subheadings: group tasks by a primary tag (no section entities).
enum TagGrouping {
    /// Meta labels — useful filters, but not list subheadings when a context tag exists.
    private static let metaNames: Set<String> = [
        "urgent", "waiting", "home", "someday", "errand", "errands"
    ]

    struct Section: Identifiable, Equatable, Sendable {
        var id: String
        var title: String
        var tasks: [TaskRecord]
    }

    /// Prefer a context tag (class, project, Work) over meta tags (Urgent, Waiting).
    static func primaryTag(from tags: [TagRecord]) -> TagRecord? {
        guard !tags.isEmpty else { return nil }
        if let context = tags.first(where: { !isMetaTagName($0.name) }) {
            return context
        }
        return tags.first
    }

    static func isMetaTagName(_ name: String) -> Bool {
        metaNames.contains(name.folding(options: .caseInsensitive, locale: .current))
    }

    /// Groups tasks under primary-tag headings; Untagged last.
    static func sections(
        tasks: [TaskRecord],
        tagsByTaskId: [String: [TagRecord]]
    ) -> [Section] {
        var buckets: [String: (title: String, tasks: [TaskRecord])] = [:]
        for task in tasks {
            let tags = tagsByTaskId[task.id] ?? []
            if let primary = primaryTag(from: tags) {
                buckets[primary.id, default: (primary.name, [])].tasks.append(task)
            } else {
                buckets["", default: ("Untagged", [])].tasks.append(task)
            }
        }
        return buckets
            .map { key, value in
                Section(
                    id: key.isEmpty ? "untagged" : key,
                    title: value.title,
                    tasks: value.tasks
                )
            }
            .sorted { lhs, rhs in
                if lhs.id == "untagged" { return false }
                if rhs.id == "untagged" { return true }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
}
