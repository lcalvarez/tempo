// Tempo · generate-plan Edge Function
//
// Calls Anthropic Sonnet 4.5 to produce a paired session plan. The iOS
// `AnthropicPlanProvider` invokes this function whenever the on-device
// `PlannerService` decides we should hit a real LLM (typically: device
// can't run Apple Foundation Models, OR Apple's tier failed validation).
//
// Why a server function instead of a direct Anthropic call from the
// client:
//
//   1. The Anthropic API key never ships in the iOS bundle.
//   2. We enforce per-user, per-day rate limits server-side via the
//      `plan_generation_log` table — even if a malicious client
//      bypasses the on-device cache, they can't spend more than one
//      Sonnet generation per `auth.uid()` per local day. The same
//      table tells us if we should serve a 429 → the client falls
//      through to its heuristic fallback.
//   3. We can swap providers (or A/B test prompts) without releasing
//      a new app build.
//
// Environment variables (set via `supabase secrets set …` for cloud,
// or in `supabase/.env` for local):
//
//     ANTHROPIC_API_KEY    sk-ant-…
//     ANTHROPIC_MODEL      claude-sonnet-4-5  (override is optional)

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ── Config ──────────────────────────────────────────────────────────

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_MODEL =
  Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-5";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// CORS so the iOS Functions client (which preflights via OPTIONS) is
// happy. Same headers we use elsewhere.
const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Types matching the iOS wire format ─────────────────────────────

interface SidePayload {
  name: string;
  fitness_level: string;
  intensity: string;
  focuses: string[];
  avoided_styles: string[];
  equipment: string[];
}

interface CatalogItem {
  id: string;
  name: string;
  muscle_groups: string[];
  kind: string;
  default_sets: number;
  default_reps: number;
  default_weight: number;
}

interface RequestBody {
  user: SidePayload;
  partner: SidePayload;
  day: number;
  catalog: CatalogItem[];
}

interface GeneratedExercise {
  catalog_id: string;
  name: string;
  sets: number;
  reps: number;
  weight: number;
  kind: string;
}

interface GeneratedPlan {
  title: string;
  subtitle: string;
  duration_minutes: number;
  muscle_groups: string[];
  you_plan: GeneratedExercise[];
  partner_title: string;
  partner_subtitle: string;
  partner_duration_minutes: number;
  partner_muscle_groups: string[];
  partner_plan: GeneratedExercise[];
}

interface AnthropicResponse {
  content: Array<{ type: string; text?: string; input?: any; name?: string }>;
}

// ── Handler ────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // 1. Authenticate the caller. The Supabase client on iOS auto-injects
  //    the user's JWT into Authorization; we use it both to identify
  //    them (for rate limiting) and as the access policy gate (anon
  //    callers can't burn AI tokens).
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) {
    return json({ error: "missing bearer token" }, 401);
  }
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userRes, error: userErr } = await supabase.auth.getUser(
    auth.slice("Bearer ".length),
  );
  if (userErr || !userRes?.user) {
    return json({ error: "invalid jwt" }, 401);
  }
  const userId = userRes.user.id;

  if (userRes.user.is_anonymous) {
    // Refuse to spend Anthropic tokens for ephemeral guest accounts —
    // exactly the cohort most likely to churn before we recoup the call.
    return json(
      { error: "anonymous accounts can't generate AI plans yet" },
      403,
    );
  }

  // 2. Rate-limit: one AI generation per local-calendar-day per user.
  //    The iOS client also caches once per day on-device; this is a
  //    defense-in-depth guard for fresh installs / cache wipes /
  //    multiple devices.
  const today = new Date();
  const todayKey = today.toISOString().slice(0, 10); // UTC day key
  const { data: existing } = await supabase
    .from("plan_generation_log")
    .select("id")
    .eq("user_id", userId)
    .eq("day_key", todayKey)
    .limit(1);
  if ((existing?.length ?? 0) > 0) {
    return json({ error: "rate limited (one generation per day)" }, 429);
  }

  // 3. Decode payload + sanity-check it.
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json body" }, 400);
  }
  if (!body?.user || !body?.partner || !Array.isArray(body?.catalog)) {
    return json({ error: "missing fields (user, partner, catalog)" }, 400);
  }

  if (!ANTHROPIC_API_KEY) {
    return json({ error: "ANTHROPIC_API_KEY not configured" }, 500);
  }

  // 4. Call Anthropic with strict JSON output via tool-use. This is the
  //    most reliable way to get structured data out of a chat model:
  //    we expose a single tool that *takes* a `GeneratedPlan` argument
  //    and force the model to call it. The function body never runs;
  //    we just lift `tool_use.input` off the response.
  const planSchema = {
    type: "object",
    required: [
      "title",
      "subtitle",
      "duration_minutes",
      "muscle_groups",
      "you_plan",
      "partner_title",
      "partner_subtitle",
      "partner_duration_minutes",
      "partner_muscle_groups",
      "partner_plan",
    ],
    properties: {
      title: { type: "string" },
      subtitle: { type: "string" },
      duration_minutes: { type: "integer", minimum: 20, maximum: 120 },
      muscle_groups: { type: "array", items: { type: "string" } },
      you_plan: {
        type: "array",
        minItems: 3,
        maxItems: 12,
        items: exerciseSchema(),
      },
      partner_title: { type: "string" },
      partner_subtitle: { type: "string" },
      partner_duration_minutes: { type: "integer", minimum: 20, maximum: 120 },
      partner_muscle_groups: { type: "array", items: { type: "string" } },
      partner_plan: {
        type: "array",
        minItems: 3,
        maxItems: 12,
        items: exerciseSchema(),
      },
    },
  };

  const systemPrompt = buildSystemPrompt();
  const userPrompt = buildUserPrompt(body);

  const anthropicReq = {
    model: ANTHROPIC_MODEL,
    max_tokens: 2048,
    system: systemPrompt,
    tools: [
      {
        name: "produce_plan",
        description: "Return the paired session plan.",
        input_schema: planSchema,
      },
    ],
    tool_choice: { type: "tool", name: "produce_plan" },
    messages: [{ role: "user", content: userPrompt }],
  };

  const upstream = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(anthropicReq),
  });

  if (!upstream.ok) {
    const text = await upstream.text();
    return json(
      { error: `anthropic error (${upstream.status})`, detail: text.slice(0, 500) },
      502,
    );
  }

  const upstreamJSON = (await upstream.json()) as AnthropicResponse;
  const toolUse = upstreamJSON.content?.find(
    (c) => c.type === "tool_use" && c.name === "produce_plan",
  );
  const plan = toolUse?.input as GeneratedPlan | undefined;
  if (!plan) {
    return json({ error: "model returned no plan" }, 502);
  }

  // 5. Log the generation so the next call today gets the 429.
  //    Best-effort: a logging failure shouldn't block returning the
  //    plan we already paid for.
  await supabase
    .from("plan_generation_log")
    .insert({ user_id: userId, day_key: todayKey })
    .select()
    .single()
    .then(() => undefined, () => undefined);

  return json({ plan }, 200);
});

// ── Helpers ────────────────────────────────────────────────────────

function exerciseSchema() {
  return {
    type: "object",
    required: ["catalog_id", "name", "sets", "reps", "weight", "kind"],
    properties: {
      catalog_id: { type: "string" },
      name: { type: "string" },
      sets: { type: "integer", minimum: 1, maximum: 6 },
      reps: { type: "integer", minimum: 1, maximum: 60 },
      weight: { type: "integer", minimum: 0 },
      kind: {
        type: "string",
        enum: [
          "strength",
          "bodyweight",
          "timedHold",
          "distance",
          "timeBased",
          "mobility",
          "stretching",
        ],
      },
    },
  };
}

function buildSystemPrompt(): string {
  return [
    "You are Tempo's session planner. You produce TWO independent",
    "session plans — one for the user, one for their partner — based on",
    "their goals, fitness level, intensity, and avoided styles.",
    "",
    "Hard rules:",
    "• Each side gets its OWN plan (no mirroring).",
    "• Pick exercises ONLY from the catalog provided in the user message.",
    "  Use the listed catalog_id verbatim. Never invent ids.",
    "• Match the listed focuses (strength, hypertrophy, endurance,",
    "  weight loss, mobility, general). If multiple, pick a primary one.",
    "• Respect avoided_styles — don't pick anything whose name contains",
    "  one of those substrings.",
    "• Scale weights to fitness_level: new ~0.55x catalog defaults,",
    "  some ~0.85x, strong ~1.0x, advanced ~1.15x. Round to the nearest 5.",
    "• 4–8 exercises per side typical; never <3 or >12.",
    "• Total duration usually 30–75 minutes. Strictly 20–120.",
    "• Titles + subtitles are 2–4 words.",
    "",
    "Always return your answer by calling the `produce_plan` tool.",
  ].join("\n");
}

function buildUserPrompt(body: RequestBody): string {
  const fmtSide = (label: string, s: SidePayload) =>
    [
      `${label}:`,
      `  name: ${s.name}`,
      `  fitness_level: ${s.fitness_level}`,
      `  intensity: ${s.intensity}`,
      `  focuses: ${s.focuses.join(", ") || "(none)"}`,
      `  avoided_styles: ${s.avoided_styles.join(", ") || "(none)"}`,
      `  equipment: ${s.equipment.join(", ") || "(none)"}`,
    ].join("\n");

  const catalogText = body.catalog
    .map(
      (c) =>
        `${c.id} | ${c.name} | ${c.muscle_groups.join("/")} | ${c.kind} | sets=${c.default_sets} reps=${c.default_reps} weight=${c.default_weight}`,
    )
    .join("\n");

  return [
    `DAY: ${body.day}`,
    fmtSide("USER", body.user),
    fmtSide("PARTNER", body.partner),
    "",
    "CATALOG (id | name | muscleGroups | kind | defaults):",
    catalogText,
    "",
    "Produce a paired session plan now via the produce_plan tool.",
  ].join("\n");
}

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
