import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const MAX_ACTIVE_KEYS = 10;
const ISSUE_PER_HOUR = 8;
const REDEEM_PER_HOUR = 30;
const MAX_BODY_BYTES = 4096;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const lengthHeader = req.headers.get("content-length");
  if (lengthHeader && Number(lengthHeader) > MAX_BODY_BYTES) {
    return json({ error: "Payload too large" }, 413);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Sync is not configured" }, 500);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const pub = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const body = await req.json().catch(() => ({}));
    const action = String((body as { action?: unknown }).action ?? "");
    const ip = clientIP(req);

    if (action === "issue") {
      await assertRate(admin, `issue:${ip}`, ISSUE_PER_HOUR);
      const existing = await userFromJwt(req, supabaseUrl, anonKey);
      if (existing) {
        const { count } = await admin
          .from("sync_keys")
          .select("id", { count: "exact", head: true })
          .eq("user_id", existing.id)
          .is("revoked_at", null);
        if ((count ?? 0) >= MAX_ACTIVE_KEYS) {
          return json(
            { error: "Too many active sync keys. Revoke one first." },
            429,
          );
        }
      }
      const user = existing ?? await createSyncUser(admin);
      const key = mintKey();
      const keyHash = await sha256Hex(normalizeKey(key));
      const { error: insertErr } = await admin.from("sync_keys").insert({
        user_id: user.id,
        key_hash: keyHash,
      });
      if (insertErr) throw insertErr;
      const email = await ensureEmail(admin, user);
      const session = await mintSession(admin, pub, email);
      return json({
        key,
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_in: session.expires_in,
        token_type: session.token_type ?? "bearer",
        user_id: user.id,
      });
    }

    if (action === "redeem") {
      await assertRate(admin, `redeem:${ip}`, REDEEM_PER_HOUR);
      const key = normalizeKey(String((body as { key?: unknown }).key ?? ""));
      if (key.length < 12) {
        return json({ error: "Unknown or revoked sync key" }, 401);
      }
      const keyHash = await sha256Hex(key);
      const { data: row, error: lookupErr } = await admin
        .from("sync_keys")
        .select("id, user_id, revoked_at")
        .eq("key_hash", keyHash)
        .maybeSingle();
      if (lookupErr) throw lookupErr;
      if (!row || row.revoked_at) {
        return json({ error: "Unknown or revoked sync key" }, 401);
      }

      const { data: userData, error: userErr } = await admin.auth.admin
        .getUserById(row.user_id);
      if (userErr || !userData.user) {
        return json({ error: "Unknown or revoked sync key" }, 401);
      }
      const email = await ensureEmail(admin, userData.user);
      const session = await mintSession(admin, pub, email);

      await admin
        .from("sync_keys")
        .update({ last_used_at: new Date().toISOString() })
        .eq("id", row.id);

      return json({
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_in: session.expires_in,
        token_type: session.token_type ?? "bearer",
        user_id: row.user_id,
      });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (err) {
    if (err instanceof RateLimitError) {
      return json({ error: "Too many attempts. Try again later." }, 429);
    }
    console.error("sync-key", err);
    return json({ error: "Something went wrong" }, 500);
  }
});

class RateLimitError extends Error {}

function clientIP(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0]?.trim() || "unknown";
  return req.headers.get("cf-connecting-ip") || "unknown";
}

async function assertRate(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  max: number,
) {
  const { data } = await admin
    .from("sync_key_rate_limits")
    .select("window_started_at, hit_count")
    .eq("bucket", bucket)
    .maybeSingle();

  const now = Date.now();
  const hour = 60 * 60 * 1000;
  if (!data || now - new Date(data.window_started_at).getTime() >= hour) {
    const { error } = await admin.from("sync_key_rate_limits").upsert({
      bucket,
      window_started_at: new Date(now).toISOString(),
      hit_count: 1,
    });
    if (error) throw error;
    return;
  }
  if (data.hit_count >= max) throw new RateLimitError();
  const { error } = await admin
    .from("sync_key_rate_limits")
    .update({ hit_count: data.hit_count + 1 })
    .eq("bucket", bucket);
  if (error) throw error;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function mintKey(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let raw = "";
  for (const b of bytes) raw += KEY_ALPHABET[b % KEY_ALPHABET.length];
  return `TTK-${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8, 12)}-${raw.slice(12, 16)}`;
}

function normalizeKey(key: string): string {
  return key.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function decodeJwtPayload(jwt: string): Record<string, unknown> | null {
  try {
    const part = jwt.split(".")[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(padded)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

async function userFromJwt(
  req: Request,
  supabaseUrl: string,
  anonKey: string,
): Promise<{ id: string; email?: string | null } | null> {
  const header = req.headers.get("Authorization") ?? "";
  const jwt = header.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return null;
  const payload = decodeJwtPayload(jwt);
  if (payload?.role !== "authenticated") return null;
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await userClient.auth.getUser(jwt);
  if (error || !data.user || data.user.is_anonymous) return null;
  return { id: data.user.id, email: data.user.email };
}

async function createSyncUser(admin: ReturnType<typeof createClient>) {
  const email = `sync.${crypto.randomUUID()}@tickytacky.invalid`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: `${crypto.randomUUID()}${crypto.randomUUID()}`,
    email_confirm: true,
    app_metadata: { providers: ["sync_key"], provider: "sync_key" },
  });
  if (error || !data.user) throw error ?? new Error("create user failed");
  return data.user;
}

async function ensureEmail(
  admin: ReturnType<typeof createClient>,
  user: { id: string; email?: string | null },
) {
  if (user.email) return user.email;
  const email = `sync.${user.id}@tickytacky.invalid`;
  const { error } = await admin.auth.admin.updateUserById(user.id, {
    email,
    email_confirm: true,
  });
  if (error) throw error;
  return email;
}

async function mintSession(
  admin: ReturnType<typeof createClient>,
  pub: ReturnType<typeof createClient>,
  email: string,
) {
  const { data, error } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  if (error || !data.properties?.hashed_token) throw error ?? new Error("link");
  const { data: verified, error: verifyError } = await pub.auth.verifyOtp({
    type: "magiclink",
    token_hash: data.properties.hashed_token,
  });
  if (verifyError || !verified.session) throw verifyError ?? new Error("otp");
  return verified.session;
}
