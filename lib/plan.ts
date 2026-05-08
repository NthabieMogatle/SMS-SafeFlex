import type { SupabaseClient } from "@supabase/supabase-js";

export const FREE_TIER_MONTHLY_LIMIT = 3;

export type PlanTier = "free" | "lifetime";

export type PlanStatus = {
  tier: PlanTier;
  usedThisMonth: number;
  monthlyLimit: number | null; // null = unlimited
  canStartInterview: boolean;
};

function startOfMonthISO(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
}

export async function loadPlanStatus(
  supabase: SupabaseClient,
  userId: string,
): Promise<PlanStatus> {
  const { data: profile } = await supabase
    .from("profiles")
    .select("plan_tier")
    .eq("user_id", userId)
    .maybeSingle();

  const tier: PlanTier =
    profile?.plan_tier === "lifetime" ? "lifetime" : "free";

  const { count } = await supabase
    .from("interviews")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", startOfMonthISO());

  const usedThisMonth = count ?? 0;
  const monthlyLimit = tier === "lifetime" ? null : FREE_TIER_MONTHLY_LIMIT;
  const canStartInterview =
    monthlyLimit === null || usedThisMonth < monthlyLimit;

  return { tier, usedThisMonth, monthlyLimit, canStartInterview };
}
