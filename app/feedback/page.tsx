import type { Metadata } from "next";
import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Your feedback",
  description: "Scored feedback on your latest mock interview.",
};

type FeedbackItem = {
  question: string;
  score: number;
  strengths: string[];
  weaknesses: string[];
  rewrite: string;
};

type InterviewRow = {
  id: string;
  score: number | null;
  feedback: FeedbackItem[] | null;
  themes: string[] | null;
  role: string | null;
  industry: string | null;
  experience_level: string | null;
  created_at: string;
};

export default async function FeedbackPage({
  searchParams,
}: {
  searchParams: { id?: string };
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const baseQuery = supabase
    .from("interviews")
    .select(
      "id, score, feedback, themes, role, industry, experience_level, created_at",
    )
    .eq("user_id", user.id);

  const { data: row } = searchParams.id
    ? await baseQuery.eq("id", searchParams.id).maybeSingle()
    : await baseQuery
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

  const interview = row as InterviewRow | null;

  if (!interview || !interview.feedback) {
    return (
      <>
        <Nav />
        <main className="mx-auto flex min-h-[80vh] max-w-xl flex-col items-center justify-center gap-4 px-6 py-12 text-center">
          {searchParams.id ? (
            <>
              <h1 className="text-xl font-semibold">
                We couldn&apos;t find that interview
              </h1>
              <p className="text-sm text-foreground/60">
                It may have been deleted, or it belongs to a different
                account.
              </p>
            </>
          ) : (
            <>
              <h1 className="text-xl font-semibold">No feedback yet</h1>
              <p className="text-sm text-foreground/60">
                Run your first mock interview and your scored feedback will
                show up here.
              </p>
            </>
          )}
          <div className="mt-2 flex flex-wrap justify-center gap-3">
            <Link
              href="/dashboard"
              className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
            >
              Go to dashboard
            </Link>
            <Link
              href="/interview?fresh=1"
              className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
            >
              Start an interview
            </Link>
          </div>
        </main>
      </>
    );
  }

  const items = interview.feedback;
  const themes = interview.themes ?? [];

  return (
    <>
      <Nav />
      <main className="mx-auto max-w-2xl px-6 py-12">
        <h1 className="mb-1 text-2xl font-semibold">Your feedback</h1>
        <p className="mb-6 text-sm text-foreground/60">
          Overall score:{" "}
          <span className="font-medium text-foreground">
            {interview.score ?? "—"}/10
          </span>
          {interview.role && (
            <>
              {" · "}
              <span>{interview.role}</span>
              {interview.industry && (
                <>
                  {" · "}
                  <span>{interview.industry}</span>
                </>
              )}
            </>
          )}
        </p>

        {themes.length > 0 && (
          <section className="mb-8 rounded-md border border-emerald-500/20 bg-emerald-500/5 p-4">
            <h2 className="mb-3 text-base font-semibold">
              📊 Top {themes.length} {themes.length === 1 ? "thing" : "things"} to
              work on
            </h2>
            <ul className="space-y-2 text-sm">
              {themes.map((t, i) => (
                <li key={i} className="flex gap-2">
                  <span aria-hidden className="text-emerald-500">
                    →
                  </span>
                  <span>{t}</span>
                </li>
              ))}
            </ul>
            <p className="mt-3 text-xs text-foreground/50">
              These are the highest-leverage patterns across your answers.
              Focus your next session here.
            </p>
          </section>
        )}

        <div className="space-y-6">
          {items.map((item, i) => (
            <article
              key={i}
              className="rounded-md border border-foreground/10 p-4"
            >
              <div className="mb-2 flex items-baseline justify-between">
                <h2 className="text-sm font-medium text-foreground/60">
                  Q{i + 1}
                </h2>
                <span className="text-sm font-semibold">{item.score}/10</span>
              </div>
              <p className="mb-3 text-base">{item.question}</p>
              {item.strengths?.length > 0 && (
                <div className="mb-3">
                  <h3 className="mb-1 text-xs font-medium uppercase tracking-wide text-emerald-600">
                    Strengths
                  </h3>
                  <ul className="list-disc space-y-1 pl-5 text-sm">
                    {item.strengths.map((s, j) => (
                      <li key={j}>{s}</li>
                    ))}
                  </ul>
                </div>
              )}
              {item.weaknesses?.length > 0 && (
                <div className="mb-3">
                  <h3 className="mb-1 text-xs font-medium uppercase tracking-wide text-amber-600">
                    Weaknesses
                  </h3>
                  <ul className="list-disc space-y-1 pl-5 text-sm">
                    {item.weaknesses.map((w, j) => (
                      <li key={j}>{w}</li>
                    ))}
                  </ul>
                </div>
              )}
              {item.rewrite && (
                <div>
                  <h3 className="mb-1 text-xs font-medium uppercase tracking-wide text-foreground/60">
                    Rewritten answer
                  </h3>
                  <p className="whitespace-pre-wrap text-sm">{item.rewrite}</p>
                </div>
              )}
            </article>
          ))}
        </div>

        <div className="mt-8 flex flex-wrap gap-3">
          <Link
            href="/dashboard"
            className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
          >
            ← Back to dashboard
          </Link>
          <Link
            href="/interview?fresh=1"
            className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
          >
            New interview
          </Link>
        </div>
      </main>
    </>
  );
}
