import type { Metadata } from "next";
import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { loadPlanStatus } from "@/lib/plan";
import Nav from "@/components/Nav";
import RedeemForm from "./RedeemForm";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Account",
  description: "Manage your Career OS plan and redeem launch codes.",
};

export default async function AccountPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const plan = await loadPlanStatus(supabase, user.id);

  return (
    <>
      <Nav />
      <main className="mx-auto max-w-2xl px-6 py-10">
        <h1 className="mb-1 text-2xl font-semibold">Account</h1>
        <p className="mb-8 text-sm text-foreground/60">{user.email}</p>

        <section className="mb-8 rounded-md border border-foreground/10 p-5">
          <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-foreground/60">
            Current plan
          </h2>
          {plan.tier === "lifetime" ? (
            <>
              <div className="mb-2 inline-flex items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-3 py-1 text-sm font-semibold text-emerald-400">
                <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
                Lifetime
              </div>
              <p className="text-sm text-foreground/70">
                Unlimited interviews, full feedback, history, and themes —
                forever. Thanks for supporting Career OS.
              </p>
            </>
          ) : (
            <>
              <div className="mb-2 inline-flex items-center gap-2 rounded-full border border-foreground/20 bg-foreground/5 px-3 py-1 text-sm font-semibold">
                Free
              </div>
              <p className="mb-3 text-sm text-foreground/70">
                {plan.usedThisMonth} of {plan.monthlyLimit} interviews used
                this month.
              </p>
              <div className="h-2 w-full overflow-hidden rounded-full bg-foreground/10">
                <div
                  className={
                    "h-full " +
                    (plan.canStartInterview ? "bg-emerald-500" : "bg-amber-500")
                  }
                  style={{
                    width: `${Math.min(100, ((plan.usedThisMonth ?? 0) / (plan.monthlyLimit ?? 1)) * 100)}%`,
                  }}
                />
              </div>
              {!plan.canStartInterview && (
                <p className="mt-3 text-xs text-amber-400">
                  You&apos;ve used all of this month&apos;s free interviews.
                  Redeem a launch code below for lifetime access, or come back
                  next month.
                </p>
              )}
            </>
          )}
        </section>

        {plan.tier === "free" && (
          <section className="mb-8 rounded-md border border-foreground/10 p-5">
            <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-foreground/60">
              Redeem a code
            </h2>
            <p className="mb-4 text-sm text-foreground/70">
              Got a launch code or AppSumo code? Enter it below to upgrade
              your account.
            </p>
            <RedeemForm />
          </section>
        )}

        <div className="flex flex-wrap gap-3">
          <Link
            href="/dashboard"
            className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
          >
            ← Back to dashboard
          </Link>
          <Link
            href="/setup"
            className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
          >
            Update profile
          </Link>
        </div>
      </main>
    </>
  );
}
