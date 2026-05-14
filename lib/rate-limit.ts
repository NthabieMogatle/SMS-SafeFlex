import { NextResponse } from "next/server";
import type { SupabaseClient } from "@supabase/supabase-js";

export type RateLimitResult = {
  ok: boolean;
  used: number;
  limit: number;
  retryAfterSeconds: number;
};

// Per-user request budget for a named bucket within a rolling time window.
// Used by the LLM-backed API routes to cap cost-overrun risk from a single
// account hammering Anthropic or OpenAI.
//
// Implementation: count-then-insert against the rate_limits table. There is
// a minor TOCTOU race (a concurrent burst can let ~1-2 extra requests
// through in the same window) — acceptable for the goal here, which is
// blocking thousands-of-calls abuse, not perfect per-millisecond enforcement.
//
// Fails open: if the rate_limits table is unreachable or returns an error,
// the request is allowed through. The reasoning is that a degraded
// rate-limiter should not take down the product; the server-side plan gate
// (lib/plan.ts) remains the primary monetization defense.
export async function checkRateLimit(
  supabase: SupabaseClient,
  userId: string,
  bucket: string,
  limit: number,
  windowSeconds: number,
): Promise<RateLimitResult> {
  const sinceIso = new Date(Date.now() - windowSeconds * 1000).toISOString();

  try {
    const { count, error } = await supabase
      .from("rate_limits")
      .select("created_at", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("bucket", bucket)
      .gte("created_at", sinceIso);

    if (error) {
      console.error("rate-limit count failed", { bucket, error });
      return { ok: true, used: 0, limit, retryAfterSeconds: 0 };
    }

    const used = count ?? 0;
    if (used >= limit) {
      return { ok: false, used, limit, retryAfterSeconds: windowSeconds };
    }

    const { error: insertError } = await supabase
      .from("rate_limits")
      .insert({ user_id: userId, bucket });

    if (insertError) {
      console.error("rate-limit insert failed", { bucket, error: insertError });
    }

    return { ok: true, used: used + 1, limit, retryAfterSeconds: 0 };
  } catch (e) {
    console.error("rate-limit unexpected error", { bucket, error: e });
    return { ok: true, used: 0, limit, retryAfterSeconds: 0 };
  }
}

export function rateLimitedResponse(result: RateLimitResult) {
  return NextResponse.json(
    {
      error:
        "You're using this endpoint very frequently. Please wait a few minutes before trying again.",
    },
    {
      status: 429,
      headers: { "Retry-After": String(result.retryAfterSeconds) },
    },
  );
}
