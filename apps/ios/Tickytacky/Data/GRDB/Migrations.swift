import GRDB

enum AppMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_lists") { db in
            try db.create(table: "lists") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("icon", .text)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("is_inbox", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            // Inbox uniqueness enforced in AppDatabase.seedInboxIfNeeded (soft-delete aware).
        }

        /// Tasks + subtasks.
        /// `due_date` is DATETIME at calendar start-of-day (date-only). Time lives in
        /// `has_due_time` + `due_hour` / `due_minute`. Soft-delete via `deleted_at`.
        migrator.registerMigration("v2_tasks") { db in
            try db.create(table: "tasks") { t in
                t.column("id", .text).primaryKey()
                t.column("list_id", .text).notNull()
                    .references("lists", onDelete: .restrict)
                t.column("title", .text).notNull()
                t.column("notes", .text)
                t.column("is_completed", .boolean).notNull().defaults(to: false)
                t.column("completed_at", .datetime)
                t.column("due_date", .datetime)
                t.column("has_due_time", .boolean).notNull().defaults(to: false)
                t.column("due_hour", .integer)
                t.column("due_minute", .integer)
                t.column("priority", .integer).notNull().defaults(to: 0)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "tasks_list_active",
                on: "tasks",
                columns: ["list_id", "deleted_at", "sort_order"]
            )
            try db.create(
                index: "tasks_due_active",
                on: "tasks",
                columns: ["due_date", "deleted_at", "is_completed"]
            )

            try db.create(table: "subtasks") { t in
                t.column("id", .text).primaryKey()
                t.column("task_id", .text).notNull()
                    .references("tasks", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("is_completed", .boolean).notNull().defaults(to: false)
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "subtasks_task_active",
                on: "subtasks",
                columns: ["task_id", "deleted_at", "sort_order"]
            )
        }

        /// Tags + task↔tag junction. Soft-delete tags via `deleted_at`.
        migrator.registerMigration("v3_tags") { db in
            try db.create(table: "tags") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "tags_name_active",
                on: "tags",
                columns: ["name", "deleted_at"]
            )

            try db.create(table: "task_tags") { t in
                t.column("task_id", .text).notNull()
                    .references("tasks", onDelete: .cascade)
                t.column("tag_id", .text).notNull()
                    .references("tags", onDelete: .cascade)
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["task_id", "tag_id"])
            }
            try db.create(
                index: "task_tags_tag",
                on: "task_tags",
                columns: ["tag_id", "task_id"]
            )
        }

        /// Recurring tasks: Codable `RecurrenceRule` JSON in `recurrence_json`.
        migrator.registerMigration("v4_recurrence") { db in
            try db.alter(table: "tasks") { t in
                t.add(column: "recurrence_json", .text)
            }
        }

        /// Schedules, weekly blocks, and one-off exceptions (Phase E).
        /// Soft-delete via `deleted_at`.
        migrator.registerMigration("v5_schedule") { db in
            try db.create(table: "schedules") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("is_active", .boolean).notNull().defaults(to: true)
                t.column("timezone", .text)
                t.column("color", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "schedules_active",
                on: "schedules",
                columns: ["is_active", "deleted_at"]
            )

            try db.create(table: "schedule_blocks") { t in
                t.column("id", .text).primaryKey()
                t.column("schedule_id", .text).notNull()
                    .references("schedules", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("notes", .text)
                t.column("weekday", .integer).notNull()
                t.column("start_hour", .integer).notNull()
                t.column("start_minute", .integer).notNull()
                t.column("end_hour", .integer).notNull()
                t.column("end_minute", .integer).notNull()
                t.column("color", .text).notNull()
                t.column("list_id", .text)
                    .references("lists", onDelete: .setNull)
                t.column("reminder_minutes_before", .integer)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "schedule_blocks_schedule_active",
                on: "schedule_blocks",
                columns: ["schedule_id", "deleted_at", "weekday", "start_hour"]
            )

            try db.create(table: "schedule_exceptions") { t in
                t.column("id", .text).primaryKey()
                t.column("block_id", .text).notNull()
                    .references("schedule_blocks", onDelete: .cascade)
                t.column("original_start", .datetime).notNull()
                t.column("type", .text).notNull()
                t.column("new_start", .datetime)
                t.column("new_end", .datetime)
                t.column("notes", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "schedule_exceptions_block_start",
                on: "schedule_exceptions",
                columns: ["block_id", "original_start", "deleted_at"]
            )
        }

        /// Task due reminders: JSON array of minutes-before-due offsets (e.g. `[0,15,60]`).
        migrator.registerMigration("v6_reminders") { db in
            try db.alter(table: "tasks") { t in
                t.add(column: "reminder_offsets_json", .text)
            }
        }

        /// Sync bookkeeping: `synced_at` per row (dirty when nil or updated_at > synced_at).
        /// `sync_meta` holds last pull/push timestamps and last error string.
        migrator.registerMigration("v7_sync") { db in
            let tables = [
                "lists", "tasks", "subtasks", "tags",
                "schedules", "schedule_blocks", "schedule_exceptions",
            ]
            for table in tables {
                try db.alter(table: table) { t in
                    t.add(column: "synced_at", .datetime)
                }
            }
            try db.create(table: "sync_meta") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }

        /// Lowercase all UUID PKs/FKs so local rows match PostgREST (case-sensitive TEXT keys).
        migrator.registerMigration("v8_normalize_ids") { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            try db.execute(sql: "UPDATE lists SET id = lower(id)")
            try db.execute(sql: "UPDATE tags SET id = lower(id)")
            try db.execute(sql: """
                UPDATE tasks SET id = lower(id), list_id = lower(list_id)
                """)
            try db.execute(sql: """
                UPDATE subtasks SET id = lower(id), task_id = lower(task_id)
                """)
            try db.execute(sql: """
                UPDATE task_tags SET task_id = lower(task_id), tag_id = lower(tag_id)
                """)
            try db.execute(sql: "UPDATE schedules SET id = lower(id)")
            try db.execute(sql: """
                UPDATE schedule_blocks SET
                  id = lower(id),
                  schedule_id = lower(schedule_id),
                  list_id = CASE WHEN list_id IS NULL THEN NULL ELSE lower(list_id) END
                """)
            try db.execute(sql: """
                UPDATE schedule_exceptions SET
                  id = lower(id),
                  block_id = lower(block_id)
                """)
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
    }
}
