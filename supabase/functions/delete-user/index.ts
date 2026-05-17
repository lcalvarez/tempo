// Tempo · delete-user Edge Function
//
// Permanently deletes the calling user's auth.users row (and, by FK
// cascade in our schema, their profile / sessions / partnerships /
// pair_invites / live_sessions / plan_generation_log rows).
//
// The user id is taken from the verified JWT — never from the request
// body — so a malicious client can't ask us to delete somebody else's
// account. We use the service-role key server-side because
// `auth.admin.deleteUser` is a privileged operation.

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) {
    return json({ error: "missing bearer token" }, 401);
  }
  const accessToken = auth.slice("Bearer ".length);

  // Service-role client — we need admin privileges to delete the user.
  // We still verify the caller's JWT via `auth.getUser` first so the
  // request is authenticated against a real session.
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: userRes, error: userErr } = await admin.auth.getUser(accessToken);
  if (userErr || !userRes?.user) {
    return json({ error: "invalid jwt" }, 401);
  }
  const userId = userRes.user.id;

  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    return json(
      { error: `couldn't delete user: ${delErr.message}` },
      500,
    );
  }
  return json({ ok: true }, 200);
});

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
