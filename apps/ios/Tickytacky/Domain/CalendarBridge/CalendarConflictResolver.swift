import Foundation

/// Pure conflict rules for calendar two-way pull. Tickytacky remains source of truth
/// when timing is ambiguous; external title/time edits apply only when they clearly
/// landed after our last successful publish.
enum CalendarConflictResolver {
    struct LocalOccurrence: Equatable, Sendable {
        var title: String
        var start: Date
        var end: Date
    }

    struct ExternalEvent: Equatable, Sendable {
        var title: String
        var start: Date
        var end: Date
        /// EventKit `lastModifiedDate` / Google `updated`, when available.
        var lastModified: Date?
    }

    enum Action: Equatable, Sendable {
        case ignore
        case applyTitle(String)
        case applyReschedule(start: Date, end: Date)
        case applyTitleAndReschedule(title: String, start: Date, end: Date)
    }

    /// Compare a local occurrence to an external event and decide how to apply pull.
    ///
    /// - If fields match → ignore.
    /// - If we never published (`lastPublishedAt` nil) → ignore (Tickytacky wins; next publish upserts).
    /// - If external `lastModified` is at or before `lastPublishedAt` → ignore (echo / our write).
    /// - Otherwise apply title and/or time diffs from external.
    static func resolve(
        local: LocalOccurrence,
        external: ExternalEvent,
        lastPublishedAt: Date?
    ) -> Action {
        let titleDiffers = normalize(local.title) != normalize(external.title)
        let timeDiffers = !sameInstant(local.start, external.start) || !sameInstant(local.end, external.end)

        guard titleDiffers || timeDiffers else { return .ignore }
        guard let lastPublishedAt else { return .ignore }

        if let externalModified = external.lastModified, externalModified <= lastPublishedAt {
            return .ignore
        }

        switch (titleDiffers, timeDiffers) {
        case (true, true):
            return .applyTitleAndReschedule(title: external.title, start: external.start, end: external.end)
        case (true, false):
            return .applyTitle(external.title)
        case (false, true):
            return .applyReschedule(start: external.start, end: external.end)
        case (false, false):
            return .ignore
        }
    }

    private static func normalize(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sameInstant(_ a: Date, _ b: Date) -> Bool {
        abs(a.timeIntervalSince(b)) < 1
    }
}
