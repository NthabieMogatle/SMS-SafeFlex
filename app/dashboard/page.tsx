import type { Metadata } from "next";
import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Dashboard",
  description: "Your interview history, score trend, and what to practice next.",
};

type FeedbackItem = {
  question: string;
  score: number;
  strengths: string[];
  weaknesses: string[];
  rewrite: string;
};

type Interview = {
  id: string;
  score: number | null;
  feedback: FeedbackItem[] | null;
  themes: string[] | null;
  role: string | null;
  industry: string | null;
  experience_level: string | null;
  created_at: string;
};

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-foreground/10 p-3">
      <div className="text-xs text-foreground/60">{label}</div>
      <div className="mt-1 text-lg font-semibold">{value}</div>
    </div>
  );
}

function ScoreBadge({ score }: { score: number }) {
  const tone =
    score >= 8
      ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/30"
      : score >= 5
        ? "bg-amber-500/15 text-amber-400 border-amber-500/30"
        : "bg-red-500/15 text-red-400 border-red-500/30";
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-sm font-semibold ${tone}`}
    >
      <span
        aria-hidden
        className={`h-1.5 w-1.5 rounded-full ${
          score >= 8
            ? "bg-emerald-500"
            : score >= 5
              ? "bg-amber-500"
              : "bg-red-500"
        }`}
      />
      {score.toFixed(1)}
    </span>
  );
}

function ScoreChart({ scores }: { scores: number[] }) {
  if (scores.length < 2) {
    return (
      <p className="text-xs text-foreground/50">
        Complete at least 2 interviews to see your trend.
      </p>
    );
  }
  const w = 600;
  const h = 140;
  const pad = 16;
  const xStep = (w - pad * 2) / (scores.length - 1);
  const y = (s: number) => pad + (h - pad * 2) * (1 - s / 10);
  const points = scores.map((s, i) => `${pad + i * xStep},${y(s)}`).join(" ");

  return (
    <svg
      viewBox={`0 0 ${w} ${h}`}
      className="w-full rounded-md border border-foreground/10 bg-foreground/5"
      role="img"
      aria-label="Interview scores over time"
    >
      {[2, 4, 6, 8].map((g) => (
        <line
          key={g}
          x1={pad}
          y1={y(g)}
          x2={w - pad}
          y2={y(g)}
          stroke="currentColor"
          strokeOpacity="0.08"
          strokeDasharray="4,4"
        />
      ))}
      <polyline
        points={points}
        fill="none"
        stroke="hsl(160 84% 50%)"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {scores.map((s, i) => (
        <circle
          key={i}
          cx={pad + i * xStep}
          cy={y(s)}
          r="3.5"
          fill="hsl(160 84% 50%)"
        />
      ))}
    </svg>
  );
}

export default async function DashboardPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: rows } = await supabase
    .from("interviews")
    .select(
      "id, score, feedback, themes, role, industry, experience_level, created_at",
    )
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(50);

  const interviews = (rows ?? []) as Interview[];
  const total = interviews.length;
  const scores = interviews
    .map((i) => Number(i.score))
    .filter((s) => Number.isFinite(s));
  const avg = scores.length
    ? scores.reduce((s, x) => s + x, 0) / scores.length
    : 0;
  const best = scores.length ? Math.max(...scores) : 0;

  const recent5 = scores.slice(0, 5);
  const previous5 = scores.slice(5, 10);
  const trend =
    recent5.length >= 3 && previous5.length >= 3
      ? recent5.reduce((s, x) => s + x, 0) / recent5.length -
        previous5.reduce((s, x) => s + x, 0) / previous5.length
      : null;

  const lastThemes = interviews[0]?.themes ?? [];

  return (
    <>
      <Nav />
      <main className="mx-auto max-w-2xl px-6 py-10">
        <div className="mb-8 flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-semibold">Dashboard</h1>
            <p className="mt-1 text-sm text-foreground/60">
              {total === 0
                ? "No interviews yet. Start your first one."
                : `${total} interview${total === 1 ? "" : "s"} so far.`}
            </p>
          </div>
          <Link
            href="/setup?new=1"
            className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
          >
            Start new interview
          </Link>
        </div>

        {total === 0 ? (
          <div className="rounded-md border border-foreground/10 p-8">
            <h2 className="mb-3 text-lg font-semibold">
              Welcome — let&apos;s run your first interview
            </h2>
            <p className="mb-6 text-sm text-foreground/70">
              In about 5 minutes you&apos;ll get scored answers, targeted
              weaknesses, and rewritten responses calibrated to your role
              and industry. After each session, your top coaching themes
              show up here.
            </p>
            <ol className="mb-6 space-y-3 text-sm">
              <li className="flex gap-3">
                <span
                  aria-hidden
                  className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-foreground/20 text-xs font-semibold"
                >
                  1
                </span>
                <span>
                  Tell us your target role, industry, and experience level.
                </span>
              </li>
              <li className="flex gap-3">
                <span
                  aria-hidden
                  className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-foreground/20 text-xs font-semibold"
                >
                  2
                </span>
                <span>Answer 5 AI-generated interview questions.</span>
              </li>
              <li className="flex gap-3">
                <span
                  aria-hidden
                  className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-foreground/20 text-xs font-semibold"
                >
                  3
                </span>
                <span>
                  Get scored feedback, rewrites, and the top 3 things to work on.
                </span>
              </li>
            </ol>
            <Link
              href="/setup"
              className="inline-flex rounded-md bg-foreground px-5 py-2.5 text-sm font-medium text-background hover:opacity-90"
            >
              Start your first interview →
            </Link>
          </div>
        ) : (
          <>
            <section className="mb-8 grid grid-cols-3 gap-3">
              <Stat label="Average" value={`${avg.toFixed(1)}/10`} />
              <Stat label="Best" value={`${best.toFixed(1)}/10`} />
              <Stat label="Sessions" value={String(total)} />
            </section>

            {trend !== null && (
              <section className="mb-8 rounded-md border border-foreground/10 p-4">
                <h2 className="mb-1 text-xs font-medium uppercase tracking-wide text-foreground/60">
                  Recent trend
                </h2>
                <p className="text-base">
                  {trend > 0.5 && (
                    <>
                      <span className="font-semibold text-emerald-500">
                        ↑ {trend.toFixed(1)}
                      </span>{" "}
                      points improvement over your last 5 sessions
                    </>
                  )}
                  {trend < -0.5 && (
                    <>
                      <span className="font-semibold text-amber-500">
                        ↓ {Math.abs(trend).toFixed(1)}
                      </span>{" "}
                      points decline over your last 5 sessions
                    </>
                  )}
                  {Math.abs(trend) <= 0.5 && (
                    <>
                      Holding steady around{" "}
                      <span className="font-semibold">
                        {(
                          recent5.reduce((s, x) => s + x, 0) / recent5.length
                        ).toFixed(1)}
                        /10
                      </span>
                    </>
                  )}
                </p>
              </section>
            )}

            <section className="mb-8">
              <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-foreground/60">
                Score over time
              </h2>
              <ScoreChart scores={[...scores].reverse()} />
            </section>

            {lastThemes.length > 0 && (
              <section className="mb-8 rounded-md border border-emerald-500/20 bg-emerald-500/5 p-4">
                <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-emerald-500">
                  Practice next
                </h2>
                <p className="mb-3 text-xs text-foreground/60">
                  From your most recent interview, focus on:
                </p>
                <ul className="space-y-2 text-sm">
                  {lastThemes.map((t, i) => (
                    <li key={i} className="flex gap-2">
                      <span aria-hidden className="text-emerald-500">
                        →
                      </span>
                      <span>{t}</span>
                    </li>
                  ))}
                </ul>
              </section>
            )}

            <section>
              <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-foreground/60">
                All sessions
              </h2>
              <ul className="space-y-2">
                {interviews.map((iv) => {
                  const score = Number(iv.score ?? 0);
                  return (
                    <li
                      key={iv.id}
                      className="flex flex-wrap items-center justify-between gap-3 rounded-md border border-foreground/10 p-3"
                    >
                      <div className="min-w-0">
                        <div className="text-sm">
                          {new Date(iv.created_at).toLocaleString(undefined, {
                            dateStyle: "medium",
                            timeStyle: "short",
                          })}
                        </div>
                        <div className="truncate text-xs text-foreground/60">
                          {iv.role ?? "Role unknown"}
                          {iv.industry ? ` · ${iv.industry}` : ""}
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <ScoreBadge score={score} />
                        <Link
                          href={`/feedback?id=${iv.id}`}
                          className="rounded-md border border-foreground/20 px-3 py-1.5 text-xs font-medium hover:bg-foreground/5"
                        >
                          View feedback
                        </Link>
                      </div>
                    </li>
                  );
                })}
              </ul>
            </section>
          </>
        )}
      </main>
    </>
  );
}
