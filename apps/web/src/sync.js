import config from "@shared/supabase-public.json";

const SESSION_KEY = "tickytacky.web.session";

export function supabaseUrl() {
  return import.meta.env.VITE_SUPABASE_URL || config.url;
}

export function anonKey() {
  return import.meta.env.VITE_SUPABASE_ANON_KEY || config.anonKey;
}

export function loadSession() {
  try {
    return JSON.parse(localStorage.getItem(SESSION_KEY) || "null");
  } catch {
    return null;
  }
}

export function saveSession(session) {
  if (session) localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  else localStorage.removeItem(SESSION_KEY);
}

function authHeaders(accessToken) {
  const token = accessToken || anonKey();
  return {
    apikey: anonKey(),
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

async function readError(res) {
  const text = await res.text();
  try {
    const json = JSON.parse(text);
    return json.msg || json.error_description || json.message || text;
  } catch {
    return text || res.statusText;
  }
}

export async function redeemSyncKey(key) {
  const res = await fetch(`${supabaseUrl()}/functions/v1/sync-key`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ action: "redeem", key }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok || payload.error) {
    throw new Error(payload.error || `Sync key failed (${res.status})`);
  }
  const session = {
    access_token: payload.access_token,
    refresh_token: payload.refresh_token,
    user: { id: userIdFromToken(payload.access_token) },
  };
  saveSession(session);
  return session;
}

export function signOut() {
  saveSession(null);
}

export function userId(session) {
  return session?.user?.id || userIdFromToken(session?.access_token) || null;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function requireUuid(id, label = "id") {
  if (!UUID_RE.test(String(id ?? ""))) throw new Error(`Invalid ${label}`);
  return String(id);
}

function userIdFromToken(accessToken) {
  if (!accessToken) return null;
  try {
    const part = accessToken.split(".")[1];
    if (!part) return null;
    const b64 = part.replaceAll("-", "+").replaceAll("_", "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const payload = JSON.parse(atob(padded));
    return payload.sub || null;
  } catch {
    return null;
  }
}

async function rest(session, path, { method = "GET", body, query = "" } = {}) {
  const token = session.access_token;
  const res = await fetch(`${supabaseUrl()}/rest/v1/${path}${query}`, {
    method,
    headers: {
      ...authHeaders(token),
      Prefer: "return=representation",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(await readError(res));
  const text = await res.text();
  return text ? JSON.parse(text) : [];
}

export async function ensureInbox(session) {
  const uid = userId(session);
  const loadLive = () =>
    rest(session, "lists", {
      query: "?is_inbox=eq.true&deleted_at=is.null&select=*",
    });
  const existing = await loadLive();
  if (existing.length) return existing[0];
  const now = new Date().toISOString();
  try {
    const rows = await rest(session, "lists", {
      method: "POST",
      body: {
        id: crypto.randomUUID(),
        user_id: uid,
        name: "Inbox",
        is_inbox: true,
        sort_order: 0,
        created_at: now,
        updated_at: now,
      },
    });
    return rows[0];
  } catch (err) {
    const retry = await loadLive();
    if (retry.length) return retry[0];
    throw err;
  }
}

export async function fetchTasks(session) {
  return rest(session, "tasks", {
    query: "?deleted_at=is.null&select=*&order=updated_at.desc",
  });
}

export async function addTask(session, inboxId, title) {
  const trimmed = String(title ?? "").trim();
  if (!trimmed) throw new Error("Title cannot be empty.");
  const uid = userId(session);
  const now = new Date().toISOString();
  const today = now.slice(0, 10);
  const rows = await rest(session, "tasks", {
    method: "POST",
    body: {
      id: crypto.randomUUID(),
      user_id: uid,
      list_id: requireUuid(inboxId, "list"),
      title: trimmed,
      is_completed: false,
      priority: "none",
      due_date: today,
      sort_order: 0,
      created_at: now,
      updated_at: now,
    },
  });
  return rows[0];
}

export async function setCompleted(session, task) {
  const now = new Date().toISOString();
  const next = !task.is_completed;
  const rows = await rest(session, "tasks", {
    method: "PATCH",
    query: `?id=eq.${requireUuid(task.id)}`,
    body: {
      is_completed: next,
      completed_at: next ? now : null,
      updated_at: now,
    },
  });
  return rows[0] || { ...task, is_completed: next, updated_at: now };
}
