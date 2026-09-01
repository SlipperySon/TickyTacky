import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, service);
    const pub = createClient(url, anon);

    const body = await req.json().catch(() => ({}));
    const action = body.action as string;
    const jwt = bearer(req);

    if (action === "issue") {
      const existing = await userFromJwt(admin, jwt);
      const user = existing ?? await createSyncUser(admin);
      const key = randomKey();
      const key_hash = await sha256Hex(normalizeKey(key));
      const { error } = await admin.from("sync_keys").insert({
        user_id: user.id,
        key_hash,
      });
      if (error) throw error;
      const email = await ensureEmail(admin, user);
      const session = await mintSession(admin, pub, email);
      return json({ key, access_token: session.access_token, refresh_token: session.refresh_token });
    }

    if (action === "redeem") {
      const key_hash = await sha256Hex(normalizeKey(String(body.key ?? "")));
      const { data: row, error } = await admin
        .from("sync_keys")
        .select("user_id")
        .eq("key_hash", key_hash)
        .is("revoked_at", null)
        .maybeSingle();
      if (error) throw error;
      if (!row) return json({ error: "Unknown or revoked sync key." }, 401);
      const { data: authUser, error: userError } = await admin.auth.admin.getUserById(row.user_id);
      if (userError || !authUser.user?.email) throw userError ?? new Error("User missing");
      await admin.from("sync_keys").update({ last_used_at: new Date().toISOString() }).eq("key_hash", key_hash);
      const session = await mintSession(admin, pub, authUser.user.email);
      return json({ access_token: session.access_token, refresh_token: session.refresh_token });
    }

    return json({ error: "action must be issue or redeem" }, 400);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function bearer(req: Request): string | null {
  const header = req.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice(7);
  if (!token || token.split(".").length !== 3) return null;
  return token;
}

async function userFromJwt(admin: ReturnType<typeof createClient>, jwt: string | null) {
  if (!jwt) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user) return null;
  if (data.user.is_anonymous) return null;
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

async function createSyncUser(admin: ReturnType<typeof createClient>) {
  const email = `sync.${crypto.randomUUID()}@tickytacky.invalid`;
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: crypto.randomUUID() + crypto.randomUUID(),
    email_confirm: true,
    app_metadata: { providers: ["sync_key"], provider: "sync_key" },
  });
  if (error || !data.user) throw error ?? new Error("Could not create sync user");
  return data.user;
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
  if (error) throw error;
  const tokenHash = data.properties.hashed_token;
  const { data: verified, error: verifyError } = await pub.auth.verifyOtp({
    type: "magiclink",
    token_hash: tokenHash,
  });
  if (verifyError || !verified.session) throw verifyError ?? new Error("Could not mint session");
  return verified.session;
}

function normalizeKey(raw: string) {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function randomKey() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let body = "";
  for (const b of bytes) body += alphabet[b % alphabet.length];
  return `TTK-${body.slice(0, 4)}-${body.slice(4, 8)}-${body.slice(8, 12)}-${body.slice(12)}`;
}

async function sha256Hex(text: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
