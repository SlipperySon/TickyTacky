# Recurrence completion policy (MVP)

**Decision (Phase D):** Completing a recurring task **advances `due_date` to the next occurrence** and keeps the **same task row**. The task stays incomplete (`is_completed = 0`, `completed_at = nil`).

- Series-only editing: edits apply to the whole series (no “this occurrence only”).
- Optional completion history / instance records are **deferred** (no `CompletionLog` in MVP).
- Upcoming shows the task on its **current** `due_date` after each advance (no multi-occurrence expansion required for MVP).

See also the header comment on `RecurrenceEngine.swift`.
