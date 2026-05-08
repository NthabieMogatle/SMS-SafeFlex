import type { Metadata } from "next";
import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { loadPlanStatus } from "@/lib/plan";
import Nav from "@/components/Nav";
import InterviewClient from "./InterviewClient";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Mock interview",
  description: "Practice your AI-generated mock interview.",
};

export default async function InterviewPage({
  searchParams,
}: {
  searchParams: { fresh?: string };
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("target_role, industry, experience_level")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!profile) redirect("/setup");

  const plan = await loadPlanStatus(supabase, user.id);
  if (!plan.canStartInterview) {
    return (
      <>
        <Nav />
        <main className="mx-auto flex min-h-[80vh] max-w-xl flex-col items-center justify-center gap-4 px-6 py-12 text-center">
          <h1 className="text-2xl font-semibold">
            You&apos;ve hit this month&apos;s free limit
          </h1>
          <p className="text-sm text-foreground/70">
            Free accounts get {plan.monthlyLimit} interviews per month.
            You&apos;ve completed {plan.usedThisMonth}. Redeem a launch code
            for lifetime access, or come back next month.
          </p>
          <div className="mt-2 flex flex-wrap justify-center gap-3">
            <Link
              href="/account"
              className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
            >
              Redeem a code
            </Link>
            <Link
              href="/dashboard"
              className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
            >
              Back to dashboard
            </Link>
          </div>
        </main>
      </>
    );
  }

  return (
    <>
      <Nav />
      <InterviewClient
        profile={profile}
        startFresh={searchParams.fresh === "1"}
      />
    </>
  );
}
