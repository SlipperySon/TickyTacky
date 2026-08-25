import Foundation
import GRDB
import Network
import Observation
import Supabase

/// Pull/push sync against Supabase. Offline local CRUD stays available without a session.
/// Realtime subscribe is deferred — sync on foreground + manual trigger.
@MainActor
@Observable
final class SyncEngine {
    static let shared = SyncEngine()

    private(set) var isSyncing = false
    private(set) var lastSyncAt: Date?
    private(set) var lastError: String?
    private(set) var statusMessage: String = "Idle"
    private(set) var pendingDirtyCount: Int = 0

    private var database: AppDatabase?
    private var pathMonitor: NWPathMonitor?
    private var isNetworkAvailable = true
    private var syncTask: Task<Void, Never>?

    var canSync: Bool {
        SupabaseClientConfig.shared.isConfigured
            && AuthService.shared.isSignedIn
            && isNetworkAvailable
    }

    private init() {}

    func configure(database: AppDatabase) {
        self.database = database
        startNetworkMonitor()
        refreshDirtyCount()
        loadPersistedStatus()
    }

    /// Best-effort sync when signed in and online. Safe to call from foreground.
    func syncIfPossible() {
        guard canSync, !isSyncing else {
            refreshDirtyCount()
            return
        }
        syncTask?.cancel()
        syncTask = Task { await performSync() }
    }

    func syncNow() async {
        guard SupabaseClientConfig.shared.isConfigured else {
            lastError = "Supabase is not configured."
            statusMessage = "Not configured"
            return
        }
        guard AuthService.shared.isSignedIn else {
            lastError = "Sign in to sync across devices."
            statusMessage = "Signed out"
            return
        }
        guard isNetworkAvailable else {
            lastError = "No network connection."
            statusMessage = "Offline"
            return
        }
        await performSync()
    }

    func refreshDirtyCount() {
        guard let database else { return }
        do {
            pendingDirtyCount = try database.dbQueue.read { db in
                try Self.countDirty(db)
            }
        } catch {
            pendingDirtyCount = 0
        }
    }

    // MARK: - Sync cycle

    private func performSync() async {
        guard let database,
              let client = SupabaseClientConfig.client,
              let userId = AuthService.shared.userId
        else { return }

        isSyncing = true
        statusMessage = "Syncing…"
        lastError = nil
        defer {
            isSyncing = false
            refreshDirtyCount()
        }

        do {
            try await bindAccountIfNeeded(database: database, userId: userId)

            try database.seedInboxIfNeeded()
            guard let localInboxId = try database.fetchInbox()?.id else {
                throw SyncError.missingInbox
            }

            let inboxId = try await reconcileInbox(
                client: client,
                database: database,
                localInboxId: localInboxId
            )

            let dirtyTaskIds = try await pushAll(client: client, database: database, userId: userId)
            try await pullAll(client: client, database: database, inboxId: inboxId)
            try reconcileActiveSchedules(database: database)
            try await pushTaskTags(
                client: client,
                database: database,
                userId: userId,
                taskIds: dirtyTaskIds
            )

            let now = Date()
            lastSyncAt = now
            statusMessage = "Up to date"
            try persistMeta(
                database: database,
                key: "last_sync_at",
                value: ISO8601DateFormatter().string(from: now)
            )
            try persistMeta(database: database, key: "last_error", value: "")
            await ReminderScheduler.shared.refresh(database: database)
        } catch is CancellationError {
            statusMessage = "Cancelled"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Sync failed"
            try? persistMeta(database: database, key: "last_error", value: error.localizedDescription)
        }
    }

    // MARK: - Account bind

    private func bindAccountIfNeeded(database: AppDatabase, userId: String) async throws {
        let bound = try await database.dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM sync_meta WHERE key = ?",
                arguments: ["account_user_id"]
            )
        }
        if let bound, bound != userId {
            try database.resetUserData()
        }
        try persistMeta(database: database, key: "account_user_id", value: userId)
    }

    // MARK: - Inbox reconciliation

    /// Align local inbox with remote live inbox before push/pull. Returns normalized inbox id.
    private func reconcileInbox(
        client: SupabaseClient,
        database: AppDatabase,
        localInboxId: String
    ) async throws -> String {
        let lists: [RemoteList] = try await client.from("lists").select().execute().value
        guard let remoteInbox = lists.first(where: { $0.is_inbox && $0.deleted_at == nil }) else {
            return RecordID.normalize(localInboxId)
        }

        let remoteId = RecordID.normalize(remoteInbox.id)
        let localId = RecordID.normalize(localInboxId)
        guard remoteId != localId else { return remoteId }

        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE tasks SET list_id = ?, updated_at = ? WHERE list_id = ? OR list_id = ?",
                arguments: [remoteId, Date(), localId, localInboxId]
            )

            if var local = try Self.fetchExisting(TaskListRecord.self, db: db, remoteId: localInboxId) {
                let now = Date()
                local.deletedAt = now
                local.isInbox = false
                local.updatedAt = now
                try local.update(db)
            }

            try SyncMapper.toLocal(list: remoteInbox).save(db)
        }

        return remoteId
    }

    // MARK: - Active schedule reconciliation

    /// Keep earliest-created active schedule; deactivate extras (local dirty → push later).
    private func reconcileActiveSchedules(database: AppDatabase) throws {
        try database.dbQueue.write { db in
            let active = try ScheduleRecord
                .filter(
                    ScheduleRecord.Columns.deletedAt == nil
                        && ScheduleRecord.Columns.isActive == true
                )
                .order(ScheduleRecord.Columns.createdAt)
                .fetchAll(db)
            guard active.count > 1 else { return }
            let now = Date()
            for var schedule in active.dropFirst() {
                schedule.isActive = false
                schedule.updatedAt = now
                try schedule.update(db)
            }
        }
    }

    // MARK: - Push

    @discardableResult
    private func pushAll(
        client: SupabaseClient,
        database: AppDatabase,
        userId: String
    ) async throws -> Set<String> {
        try await pushEntity(
            client: client,
            database: database,
            table: "lists",
            dirty: try await database.dbQueue.read { db in
                try TaskListRecord
                    .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                    .fetchAll(db)
            },
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(list: $0, userId: userId) }
        )

        try await pushEntity(
            client: client,
            database: database,
            table: "tags",
            dirty: try await database.dbQueue.read { db in
                try TagRecord
                    .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                    .fetchAll(db)
            },
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(tag: $0, userId: userId) }
        )

        let dirtyTasks = try await database.dbQueue.read { db in
            try TaskRecord
                .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                .fetchAll(db)
        }
        try await pushEntity(
            client: client,
            database: database,
            table: "tasks",
            dirty: dirtyTasks,
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(task: $0, userId: userId) }
        )

        try await pushEntity(
            client: client,
            database: database,
            table: "subtasks",
            dirty: try await database.dbQueue.read { db in
                try SubtaskRecord
                    .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                    .fetchAll(db)
            },
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(subtask: $0, userId: userId) }
        )

        try await pushEntity(
            client: client,
            database: database,
            table: "schedules",
            dirty: try await database.dbQueue.read { db in
                try ScheduleRecord
                    .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                    .fetchAll(db)
            },
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(schedule: $0, userId: userId) }
        )

        try await pushEntity(
            client: client,
            database: database,
            table: "schedule_blocks",
            dirty: try await database.dbQueue.read { db in
                try ScheduleBlockRecord
                    .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                    .fetchAll(db)
            },
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(block: $0, userId: userId) }
        )

        try await pushEntity(
            client: client,
            database: database,
            table: "schedule_exceptions",
            dirty: try await database.dbQueue.read { db in
                try ScheduleExceptionRecord
                    .filter(sql: "synced_at IS NULL OR updated_at > synced_at")
                    .fetchAll(db)
            },
            id: \.id,
            updatedAt: \.updatedAt,
            toRemote: { SyncMapper.toRemote(exception: $0, userId: userId) }
        )

        return Set(dirtyTasks.map(\.id))
    }

    private func pushEntity<Local: Sendable, Remote: Encodable & Sendable>(
        client: SupabaseClient,
        database: AppDatabase,
        table: String,
        dirty: [Local],
        id: KeyPath<Local, String> & Sendable,
        updatedAt: KeyPath<Local, Date> & Sendable,
        toRemote: @Sendable (Local) -> Remote
    ) async throws {
        guard !dirty.isEmpty else { return }

        var toPush: [Remote] = []
        var toMark: [(id: String, updatedAt: Date)] = []
        for row in dirty {
            let localId = row[keyPath: id]
            let rowId = RecordID.normalize(localId)
            let localUpdated = row[keyPath: updatedAt]
            if let remoteUpdated = try await fetchRemoteUpdatedAt(client: client, table: table, id: rowId),
               remoteUpdated > localUpdated
            {
                continue
            }
            toPush.append(toRemote(row))
            toMark.append((localId, localUpdated))
        }
        guard !toPush.isEmpty else { return }

        try await client.from(table)
            .upsert(toPush, onConflict: "id")
            .execute()

        let marked = toMark
        try await database.dbQueue.write { db in
            for item in marked {
                try Self.markSynced(
                    db: db,
                    table: table,
                    id: item.id,
                    expectedUpdatedAt: item.updatedAt
                )
            }
        }
    }

    /// Only bumps `synced_at` when `updated_at` is unchanged (avoids clobbering concurrent local edits).
    nonisolated private static func markSynced(
        db: Database,
        table: String,
        id: String,
        expectedUpdatedAt: Date
    ) throws {
        try db.execute(
            sql: "UPDATE \(table) SET synced_at = updated_at WHERE id = ? AND updated_at = ?",
            arguments: [id, expectedUpdatedAt]
        )
    }

    private func pushTaskTags(
        client: SupabaseClient,
        database: AppDatabase,
        userId: String,
        taskIds: Set<String>
    ) async throws {
        guard !taskIds.isEmpty else { return }

        for taskId in taskIds {
            let normalizedTaskId = RecordID.normalize(taskId)
            let links = try await database.dbQueue.read { db in
                try TaskTagRecord
                    .filter(TaskTagRecord.Columns.taskId == taskId)
                    .fetchAll(db)
            }

            let remoteLinks: [RemoteTaskTag] = try await client.from("task_tags")
                .select()
                .eq("task_id", value: normalizedTaskId)
                .execute()
                .value

            let localKeys = Set(links.map { RecordID.normalize($0.tagId) })
            for remote in remoteLinks where !localKeys.contains(RecordID.normalize(remote.tag_id)) {
                try await client.from("task_tags")
                    .delete()
                    .eq("task_id", value: remote.task_id)
                    .eq("tag_id", value: remote.tag_id)
                    .execute()
            }

            if !links.isEmpty {
                let payload = links.map {
                    RemoteTaskTag(
                        task_id: RecordID.normalize($0.taskId),
                        tag_id: RecordID.normalize($0.tagId),
                        user_id: userId,
                        created_at: $0.createdAt
                    )
                }
                try await client.from("task_tags")
                    .upsert(payload, onConflict: "task_id,tag_id")
                    .execute()
            }
        }
    }

    // MARK: - Pull

    private func pullAll(client: SupabaseClient, database: AppDatabase, inboxId: String) async throws {
        let lists: [RemoteList] = try await client.from("lists").select().execute().value
        try await database.dbQueue.write { db in
            for remote in lists {
                let existing = try Self.fetchExisting(TaskListRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(list: remote)
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let tags: [RemoteTag] = try await client.from("tags").select().execute().value
        try await database.dbQueue.write { db in
            for remote in tags {
                let existing = try Self.fetchExisting(TagRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(tag: remote)
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let tasks: [RemoteTask] = try await client.from("tasks").select().execute().value
        try await database.dbQueue.write { db in
            for remote in tasks {
                let existing = try Self.fetchExisting(TaskRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(
                        task: remote,
                        inboxId: inboxId,
                        preservingRemindersFrom: existing
                    )
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let subtasks: [RemoteSubtask] = try await client.from("subtasks").select().execute().value
        try await database.dbQueue.write { db in
            for remote in subtasks {
                let existing = try Self.fetchExisting(SubtaskRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(subtask: remote)
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let schedules: [RemoteSchedule] = try await client.from("schedules").select().execute().value
        try await database.dbQueue.write { db in
            for remote in schedules {
                let existing = try Self.fetchExisting(ScheduleRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(schedule: remote, preservingTimezoneFrom: existing)
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let blocks: [RemoteScheduleBlock] = try await client.from("schedule_blocks").select().execute().value
        try await database.dbQueue.write { db in
            for remote in blocks {
                let existing = try Self.fetchExisting(ScheduleBlockRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(block: remote)
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let exceptions: [RemoteScheduleException] = try await client.from("schedule_exceptions").select().execute().value
        try await database.dbQueue.write { db in
            for remote in exceptions {
                let existing = try Self.fetchExisting(ScheduleExceptionRecord.self, db: db, remoteId: remote.id)
                if Self.shouldApplyRemote(
                    localUpdated: existing?.updatedAt,
                    localSynced: existing?.syncedAt,
                    remoteUpdated: remote.updated_at
                ) {
                    let local = SyncMapper.toLocal(exception: remote)
                    if let existing, existing.id != local.id {
                        try existing.delete(db)
                    }
                    try local.save(db)
                }
            }
        }

        let taskTags: [RemoteTaskTag] = try await client.from("task_tags").select().execute().value
        try await database.dbQueue.write { db in
            let byTask = Dictionary(grouping: taskTags, by: { RecordID.normalize($0.task_id) })
            let localTasks = try TaskRecord.fetchAll(db)
            for task in localTasks {
                if SyncMapper.isDirty(updatedAt: task.updatedAt, syncedAt: task.syncedAt) {
                    continue
                }
                let remoteLinks = byTask[RecordID.normalize(task.id)] ?? []
                try TaskTagRecord
                    .filter(TaskTagRecord.Columns.taskId == task.id)
                    .deleteAll(db)
                for link in remoteLinks {
                    try TaskTagRecord(
                        taskId: RecordID.normalize(link.task_id),
                        tagId: RecordID.normalize(link.tag_id),
                        createdAt: link.created_at
                    ).insert(db)
                }
            }
        }
    }

    // MARK: - LWW helpers

    /// Never clobber dirty local. If clean and local is newer, keep local. Else apply remote.
    nonisolated static func shouldApplyRemote(
        localUpdated: Date?,
        localSynced: Date?,
        remoteUpdated: Date
    ) -> Bool {
        guard let localUpdated else { return true }
        if SyncMapper.isDirty(updatedAt: localUpdated, syncedAt: localSynced) {
            return false
        }
        if localUpdated > remoteUpdated {
            return false
        }
        return true
    }

    /// Prefer normalized id; fall back to raw remote id for legacy uppercase rows.
    nonisolated private static func fetchExisting<T: FetchableRecord & PersistableRecord>(
        _ type: T.Type,
        db: Database,
        remoteId: String
    ) throws -> T? {
        let normalized = RecordID.normalize(remoteId)
        if let found = try T.fetchOne(db, key: normalized) {
            return found
        }
        if remoteId != normalized {
            return try T.fetchOne(db, key: remoteId)
        }
        return nil
    }

    private func fetchRemoteUpdatedAt(client: SupabaseClient, table: String, id: String) async throws -> Date? {
        struct Row: Decodable { var updated_at: Date }
        let rows: [Row] = try await client.from(table)
            .select("updated_at")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first?.updated_at
    }

    // MARK: - Meta / network

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                if path.status == .satisfied {
                    self?.syncIfPossible()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.tickytacky.sync.network"))
    }

    private func loadPersistedStatus() {
        guard let database else { return }
        do {
            let raw = try database.dbQueue.read { db in
                try String.fetchOne(
                    db,
                    sql: "SELECT value FROM sync_meta WHERE key = ?",
                    arguments: ["last_sync_at"]
                )
            }
            if let raw, let date = ISO8601DateFormatter().date(from: raw) {
                lastSyncAt = date
                statusMessage = "Last sync \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            let err = try database.dbQueue.read { db in
                try String.fetchOne(
                    db,
                    sql: "SELECT value FROM sync_meta WHERE key = ?",
                    arguments: ["last_error"]
                )
            }
            if let err, !err.isEmpty {
                lastError = err
            }
        } catch {
            // Ignore meta load failures on launch.
        }
    }

    private func persistMeta(database: AppDatabase, key: String, value: String) throws {
        try database.dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO sync_meta(key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                arguments: [key, value]
            )
        }
    }

    private static func countDirty(_ db: Database) throws -> Int {
        let tables = [
            "lists", "tasks", "subtasks", "tags",
            "schedules", "schedule_blocks", "schedule_exceptions"
        ]
        var count = 0
        for table in tables {
            count += try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*) FROM \(table)
                WHERE synced_at IS NULL OR updated_at > synced_at
                """
            ) ?? 0
        }
        return count
    }
}

enum SyncError: LocalizedError {
    case missingInbox

    var errorDescription: String? {
        switch self {
        case .missingInbox: "Inbox list is missing."
        }
    }
}
