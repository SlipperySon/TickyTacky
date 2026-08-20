# ReminderScheduler (Phase G)

Local notifications for task due reminders and timetable block reminders.

## Simulator vs device

- **Simulator:** Permission prompts and pending-request APIs work; reliable *delivery* of timed local notifications is limited / flaky. Prefer a physical iPhone for fire tests.
- **Device:** True fire + banner behavior for G8 exit criteria.

## Identifiers

Stable and idempotent (re-scheduling replaces the same id):

| Kind | Pattern |
|------|---------|
| Task | `tt.task.{taskId}.{offsetMinutes}` |
| Block occurrence | `tt.block.{blockId}.{yyyyMMddHHmmss}.{minutesBefore}` |

## Budget

iOS caps pending local notifications (~64). `ReminderRequestBuilder.prioritize` keeps the soonest N (`pendingBudget = 64`).

## Permission timing

Ask after the user first enables a reminder (task or block), not on cold launch. Settings shows status and links to system Settings when denied.

## Soft-delete / complete

Completed and soft-deleted tasks are omitted. Soft-deleted blocks / skipped occurrences are omitted via OccurrenceGenerator.
