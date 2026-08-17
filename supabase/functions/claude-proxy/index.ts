// supabase/functions/claude-proxy/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// SkinMate — Claude API proxy (keeps the API key server-side)
//
// Handles three action types:
//   "ocr"        → Step 1: extract ingredient list from a product label image
//   "classify"   → Step 2: classify each ingredient (safe / irritant / allergen)
//   "explain"    → Step 4: generate personalised risk explanation
//
// Deploy:
//   supabase functions deploy claude-proxy
//
// Set the secret once:
//   supabase secrets set CLAUDE_API_KEY=sk-ant-...
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
const CLAUDE_MODEL   = "claude-haiku-4-5";

// ── CORS headers (allow your Flutter app / Supabase client) ──────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Helper: call Claude with automatic retry on 429 ──────────────────────────
async function callClaude(
  body: Record<string, unknown>,
  maxRetries = 4,
): Promise<Response> {
  const apiKey = Deno.env.get("CLAUDE_API_KEY");
  if (!apiKey) throw new Error("CLAUDE_API_KEY secret is not set.");

  let delayMs = 4000;
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const res = await fetch(CLAUDE_API_URL, {
      method:  "POST",
      headers: {
        "Content-Type":      "application/json",
        "x-api-key":         apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });

    if (res.status !== 429) return res;

    // Rate-limited — wait and retry
    if (attempt < maxRetries - 1) {
      await new Promise((r) => setTimeout(r, delayMs));
      delayMs *= 2;
    }
  }
  throw new Error("Claude API rate-limited after maximum retries. Please wait and try again.");
}

// ── Helper: extract text from Claude response body ───────────────────────────
async function claudeText(res: Response): Promise<string> {
  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Claude API error ${res.status}: ${JSON.stringify(data)}`);
  }
  // data.content is an array of content blocks; first text block is the reply
  const block = (data.content as Array<{ type: string; text?: string }>)
    .find((b) => b.type === "text");
  return (block?.text ?? "").trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION 1 — OCR
// Receives a base64 JPEG of the product label.
// Returns: { found: boolean, ingredients: string[] }
// ─────────────────────────────────────────────────────────────────────────────
async function handleOcr(base64Image: string): Promise<Record<string, unknown>> {
  const prompt = `Look at this cosmetic product label image carefully.
Find the ingredient list — typically a dense block of comma-separated INCI names.
Extract every ingredient name exactly as written on the label.

Rules:
- Do NOT require the word "INGREDIENTS" to be present — look for INCI-style text.
- Include all names you can read, even if the text is small or partially visible.
- "Aqua" or "Water" is almost always first if the list is visible.
- Set "found" to false ONLY if there is truly no readable ingredient text at all.

Respond ONLY in this exact JSON format (no markdown, no extra text):
{"found": true, "ingredients": ["Aqua", "Glycerin", "Niacinamide"]}
or:
{"found": false, "ingredients": []}`;

  const raw = await callClaude({
    model:      CLAUDE_MODEL,
    max_tokens: 1200,
    messages: [
      {
        role: "user",
        content: [
          {
            type:   "image",
            source: { type: "base64", media_type: "image/jpeg", data: base64Image },
          },
          { type: "text", text: prompt },
        ],
      },
    ],
  });

  const text = await claudeText(raw);

  // Strip markdown fences if Claude adds them despite instructions
  const cleaned = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();

  try {
    const parsed = JSON.parse(cleaned) as { found: boolean; ingredients: string[] };
    const ingredients = (parsed.ingredients ?? [])
      .map((s: string) => s.trim())
      .filter((s: string) => s.length > 1 && s !== "[unclear]");

    return {
      found:       parsed.found && ingredients.length > 0,
      ingredients: ingredients,
    };
  } catch {
    // JSON parse failed — salvage comma-separated names from raw text
    const fallback = cleaned
      .replace(/["{}[\]]/g, "")
      .split(",")
      .map((s) => s.trim())
      .filter((s) => s.length > 2 && !s.toLowerCase().includes("found"));

    return {
      found:       fallback.length > 0,
      ingredients: fallback,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION 2 — CLASSIFY
// Receives ingredient names + user skin profile.
// Returns: Array<{ name, category, reason, skin_type_note }>
// ─────────────────────────────────────────────────────────────────────────────
async function handleClassify(
  ingredients: string[],
  skinType:    string,
  skinConcern: string,
): Promise<unknown[]> {
  if (ingredients.length === 0) return [];

  // Process in batches of 40 (Haiku comfortably handles this in one call)
  const BATCH = 40;
  const results: unknown[] = [];

  for (let i = 0; i < ingredients.length; i += BATCH) {
    const batch = ingredients.slice(i, i + BATCH);
    const list  = batch.map((n, idx) => `${idx + 1}. ${n}`).join("\n");

    const prompt = `You are SkinMate, an expert cosmetic chemist and dermatologist AI.

Classify each ingredient as one of:
- "safe"     — generally well-tolerated, low irritation potential
- "irritant" — may cause irritation, redness, or sensitivity in some people  
- "allergen" — known allergen, sensitizer, or high-risk (fragrances, preservatives, formaldehyde-releasers)

User skin type:    ${skinType || "not specified"}
User skin concern: ${skinConcern || "not specified"}

Ingredients to classify:
${list}

Respond ONLY with a JSON array, one object per ingredient in the same order.
No markdown. No extra text. Only valid JSON:
[
  {
    "name": "exact name from the list above",
    "category": "safe" | "irritant" | "allergen",
    "reason": "one sentence explanation",
    "skin_type_note": "personalised note for this user's skin, or null"
  }
]`;

    const raw  = await callClaude({
      model:      CLAUDE_MODEL,
      max_tokens: 2000,
      messages:   [{ role: "user", content: prompt }],
    });
    const text = await claudeText(raw);

    try {
      const cleaned = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim();
      const parsed  = JSON.parse(cleaned) as unknown[];
      results.push(...parsed);
    } catch {
      // Fallback: mark entire batch as safe if parsing fails
      batch.forEach((name) =>
        results.push({ name, category: "safe", reason: "Could not classify.", skin_type_note: null })
      );
    }
  }

  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION 3 — EXPLAIN
// Receives the full risk assessment summary.
// Returns: string (plain-text explanation, 3–5 sentences)
// ─────────────────────────────────────────────────────────────────────────────
async function handleExplain(payload: {
  ingredientCount: number;
  allergens:       string[];
  irritants:       string[];
  flaggedSummary:  string;
  totalScore:      number;
  levelLabel:      string;
  skinType:        string;
  skinConcern:     string;
}): Promise<string> {
  const {
    ingredientCount, allergens, irritants,
    flaggedSummary, totalScore, levelLabel,
    skinType, skinConcern,
  } = payload;

  const prompt = `You are SkinMate AI, a friendly skincare advisor.

A rule-based engine and an AI classifier have already assessed this product.
Your ONLY job: explain the result clearly and give personalised advice.
Do NOT recalculate or question the score.

=== PRODUCT ANALYSIS ===
Total ingredients detected: ${ingredientCount}
Allergens found:  ${allergens.length > 0 ? allergens.join(", ") : "None"}
Irritants found:  ${irritants.length > 0 ? irritants.join(", ") : "None"}

Flagged ingredients (rule engine + AI):
${flaggedSummary || "None detected."}

Risk score: ${totalScore} / 100
Risk level: ${levelLabel}

=== USER SKIN PROFILE ===
Skin type:    ${skinType    || "Not specified"}
Skin concern: ${skinConcern || "Not specified"}

=== YOUR RESPONSE ===
Write 3–5 plain sentences (no markdown, no bullets, no headers):
1. What this risk level means for their specific skin type.
2. The one or two most important flagged ingredients and why they matter for this user.
3. One clear, actionable recommendation (e.g. "patch test first", "avoid if sensitive", "safe to use").

Keep language warm, simple, and practical.`;

  const raw  = await callClaude({
    model:      CLAUDE_MODEL,
    max_tokens: 400,
    messages:   [{ role: "user", content: prompt }],
  });

  return await claudeText(raw);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN HANDLER
// ─────────────────────────────────────────────────────────────────────────────
serve(async (req: Request) => {
  // Pre-flight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body   = await req.json() as Record<string, unknown>;
    const action = body.action as string;

    let result: unknown;

    switch (action) {
      case "ocr": {
        const base64Image = body.base64Image as string;
        if (!base64Image) throw new Error('Missing "base64Image" for OCR action.');
        result = await handleOcr(base64Image);
        break;
      }

      case "classify": {
  const ingredients = body.ingredients as string[];
  const skinType    = (body.skinType    as string) ?? "";
  const skinConcern = (body.skinConcern as string) ?? "";
  if (!ingredients?.length) throw new Error('Missing "ingredients" for classify action.');
  const classifications = await handleClassify(ingredients, skinType, skinConcern);
  result = { classifications };
  break;
}
      case "explain": {
  const explanation = await handleExplain(body as Parameters<typeof handleExplain>[0]);
  result = { explanation };
  break;
}
      default:
        throw new Error(`Unknown action "${action}". Expected: ocr | classify | explain`);
    }

    return new Response(JSON.stringify({ ok: true, data: result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[claude-proxy]", message);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});