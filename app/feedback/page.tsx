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

export default async function FeedbackPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: latest } = await supabase
    .from("interviews")
    .select("id, score, feedback, created_at")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!latest || !latest.feedback) {
    return (
      <>
        <Nav />
        <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-4 px-6 py-12 text-center">
          <p className="text-foreground/70">No interviews yet.</p>
          <Link
            href="/interview"
            className="rounded-md bg-foreground px-5 py-2.5 text-sm font-medium text-background hover:opacity-90"
          >
            Start one
          </Link>
        </main>
      </>
    );
  }

  const items = latest.feedback as FeedbackItem[];

  return (
    <>
      <Nav />
      <main className="mx-auto max-w-2xl px-6 py-12">
      <h1 className="mb-1 text-2xl font-semibold">Your feedback</h1>
      <p className="mb-6 text-sm text-foreground/60">
        Overall score:{" "}
        <span className="font-medium text-foreground">
          {latest.score ?? "—"}/10
        </span>
      </p>
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
      <div className="mt-8 flex gap-3">
        <Link
          href="/setup"
          className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
        >
          Update profile
        </Link>
        <Link
          href="/interview"
          className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
        >
          New interview
        </Link>
      </div>
      </main>
    </>
  );
}
