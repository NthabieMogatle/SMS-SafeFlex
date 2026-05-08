import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import Nav from "@/components/Nav";

export const dynamic = "force-dynamic";

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

function ScoreChart({ scores }: { scores: number[] }) {
  if (scores.length < 2) {
    return (
      <p className="text-xs text-foreground/50">
        Complete at least 2 interviews to see a trend.
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

export default async function HistoryPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: rows } = await supabase
    .from("interviews")
    .select("id, score, feedback, created_at")
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

  const lastFeedback = interviews[0]?.feedback ?? [];
  const lastWeaknesses = lastFeedback
    .flatMap((f) => f.weaknesses ?? [])
    .slice(0, 4);

  return (
    <>
      <Nav />
      <main className="mx-auto max-w-2xl px-6 py-10">
        <h1 className="mb-1 text-2xl font-semibold">Your progress</h1>
        <p className="mb-8 text-sm text-foreground/60">
          {total === 0
            ? "No interviews yet. Start your first one below."
            : `${total} interview${total === 1 ? "" : "s"} so far.`}
        </p>

        {total > 0 && (
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

            {lastWeaknesses.length > 0 && (
              <section className="mb-8 rounded-md border border-amber-500/20 bg-amber-500/5 p-4">
                <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-amber-500">
                  Practice next
                </h2>
                <p className="mb-3 text-xs text-foreground/60">
                  Based on your most recent feedback, focus on:
                </p>
                <ul className="space-y-2 text-sm">
                  {lastWeaknesses.map((w, i) => (
                    <li key={i} className="flex gap-2">
                      <span aria-hidden className="text-amber-500">
                        •
                      </span>
                      <span>{w}</span>
                    </li>
                  ))}
                </ul>
              </section>
            )}

            <section className="mb-8">
              <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-foreground/60">
                All sessions
              </h2>
              <ul className="space-y-2">
                {interviews.map((iv, idx) => (
                  <li
                    key={iv.id}
                    className="flex items-center justify-between rounded-md border border-foreground/10 p-3"
                  >
                    <div>
                      <div className="text-sm">
                        {new Date(iv.created_at).toLocaleString(undefined, {
                          dateStyle: "medium",
                          timeStyle: "short",
                        })}
                      </div>
                      <div className="text-xs text-foreground/60">
                        {idx === 0 ? "Most recent" : `${iv.feedback?.length ?? 5} questions`}
                      </div>
                    </div>
                    <div className="text-base font-semibold">
                      {Number(iv.score ?? 0).toFixed(1)}
                      <span className="text-xs text-foreground/50">/10</span>
                    </div>
                  </li>
                ))}
              </ul>
            </section>
          </>
        )}

        <div className="flex gap-3">
          <Link
            href="/feedback"
            className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
          >
            Latest feedback
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
