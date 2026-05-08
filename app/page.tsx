import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { Wordmark } from "@/components/Logo";

export const dynamic = "force-dynamic";

const FEATURES = [
  {
    title: "Calibrated to your role",
    body: "Pick your target role, industry, and experience level. Career OS generates 5 questions tuned to that exact profile — no generic 'tell me about yourself' filler.",
  },
  {
    title: "Honest scoring",
    body: "Each answer scored 0–10 with a senior-hiring-manager rubric. No grade inflation: empty answers get 0, average answers get 5, only excellent answers get 9+.",
  },
  {
    title: "Top 3 things to work on",
    body: "After every interview, Claude reads all your weaknesses and surfaces the 3 highest-leverage patterns to focus on next session. Coaching, not just scoring.",
  },
  {
    title: "Rewritten answers",
    body: "Every weak answer comes back rewritten in your voice — what a 9/10 version of YOUR answer looks like. Not generic templates.",
  },
  {
    title: "Progress over time",
    body: "Score chart, trend callout, and a Practice next card that remembers what you struggled with last session. Cross-session memory built in.",
  },
  {
    title: "Auto-saved drafts",
    body: "Lose your tab, get interrupted, switch devices? Your in-progress interview is saved as you type. Resume exactly where you left off.",
  },
];

const STEPS = [
  {
    n: "1",
    title: "Tell us your goal",
    body: "Target role, industry, experience level. 30 seconds.",
  },
  {
    n: "2",
    title: "Answer 5 questions",
    body: "1 behavioral, 2 technical, 1 systems-design, 1 culture-fit. Type at your own pace.",
  },
  {
    n: "3",
    title: "Get coached, not just graded",
    body: "Per-question scores, the top 3 themes, and rewritten answers — all in under a minute.",
  },
];

export default async function HomePage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) redirect("/interview");

  return (
    <main className="mx-auto max-w-3xl px-6 py-12">
      {/* Header */}
      <header className="mb-16 flex items-center justify-between">
        <Wordmark variant="light" className="h-7 w-auto" />
        <Link
          href="/login"
          className="rounded-md border border-foreground/20 px-3 py-1.5 text-xs font-medium hover:bg-foreground/5"
        >
          Log in
        </Link>
      </header>

      {/* Hero */}
      <section className="mb-20 text-center sm:mb-28">
        <p className="mb-4 inline-flex items-center gap-2 rounded-full border border-cyan-500/30 bg-cyan-500/10 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-cyan-300">
          <span aria-hidden className="h-1.5 w-1.5 rounded-full bg-cyan-400" />
          AI Interview Coach
        </p>
        <h1 className="mx-auto max-w-2xl text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl">
          AI mock interviews that actually help you{" "}
          <span className="text-cyan-400">improve.</span>
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-base text-foreground/70 sm:text-lg">
          Get scored answers, targeted feedback, and rewritten responses
          calibrated to your role, industry, and experience. Practice until
          your next interview feels easy.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link
            href="/signup"
            className="rounded-md bg-foreground px-6 py-3 text-sm font-semibold text-background hover:opacity-90"
          >
            Start practicing free →
          </Link>
          <Link
            href="/login"
            className="rounded-md border border-foreground/20 px-6 py-3 text-sm font-semibold hover:bg-foreground/5"
          >
            I have an account
          </Link>
        </div>
        <p className="mt-4 text-xs text-foreground/50">
          3 interviews per month free. No card required.
        </p>
      </section>

      {/* How it works */}
      <section className="mb-20 sm:mb-28">
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-foreground/60">
          How it works
        </h2>
        <p className="mb-10 text-2xl font-semibold sm:text-3xl">
          Practice → score → improve, in 5 minutes.
        </p>
        <ol className="grid gap-6 sm:grid-cols-3">
          {STEPS.map((s) => (
            <li
              key={s.n}
              className="rounded-md border border-foreground/10 p-5"
            >
              <div className="mb-3 flex h-8 w-8 items-center justify-center rounded-full border border-cyan-500/30 bg-cyan-500/10 text-sm font-semibold text-cyan-300">
                {s.n}
              </div>
              <h3 className="mb-1 text-base font-semibold">{s.title}</h3>
              <p className="text-sm text-foreground/70">{s.body}</p>
            </li>
          ))}
        </ol>
      </section>

      {/* Features */}
      <section className="mb-20 sm:mb-28">
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-foreground/60">
          What makes it different
        </h2>
        <p className="mb-10 text-2xl font-semibold sm:text-3xl">
          Built like a coach, not a quiz.
        </p>
        <div className="grid gap-4 sm:grid-cols-2">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="rounded-md border border-foreground/10 p-5"
            >
              <h3 className="mb-2 text-base font-semibold">{f.title}</h3>
              <p className="text-sm text-foreground/70">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Sample feedback preview */}
      <section className="mb-20 sm:mb-28">
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-foreground/60">
          The feedback you&apos;ll get
        </h2>
        <p className="mb-10 text-2xl font-semibold sm:text-3xl">
          Specific. Honest. Actionable.
        </p>
        <div className="space-y-4">
          <div className="rounded-md border border-emerald-500/20 bg-emerald-500/5 p-4">
            <p className="mb-2 text-sm font-semibold">📊 Top 3 things to work on</p>
            <ul className="space-y-1.5 text-sm">
              <li className="flex gap-2">
                <span className="text-emerald-500">→</span>
                <span>
                  Add specific metrics to quantify your impact
                </span>
              </li>
              <li className="flex gap-2">
                <span className="text-emerald-500">→</span>
                <span>
                  Use the STAR structure more consistently in behavioral answers
                </span>
              </li>
              <li className="flex gap-2">
                <span className="text-emerald-500">→</span>
                <span>
                  Reference industry-specific frameworks (e.g. PCI-DSS) when
                  relevant
                </span>
              </li>
            </ul>
          </div>
          <div className="rounded-md border border-foreground/10 p-4">
            <div className="mb-2 flex items-baseline justify-between">
              <p className="text-xs font-medium uppercase tracking-wider text-foreground/60">
                Q3
              </p>
              <span className="text-sm font-semibold">7/10</span>
            </div>
            <p className="mb-3 text-sm">
              How would you approach testing a payment processing feature to
              ensure transactions are handled correctly?
            </p>
            <p className="mb-1 text-xs font-medium uppercase tracking-wider text-amber-500">
              Weaknesses
            </p>
            <ul className="list-disc space-y-1 pl-5 text-sm text-foreground/80">
              <li>
                Did not address security testing, which was explicitly
                mentioned in the question
              </li>
              <li>
                Lacks discussion of edge cases, error handling testing, or
                compliance validation
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section className="mb-20 sm:mb-28">
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-foreground/60">
          Pricing
        </h2>
        <p className="mb-10 text-2xl font-semibold sm:text-3xl">
          Start free, upgrade when you&apos;re ready.
        </p>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="rounded-md border border-foreground/10 p-6">
            <p className="mb-1 text-sm font-medium text-foreground/60">Free</p>
            <p className="mb-4 text-3xl font-semibold">$0</p>
            <ul className="mb-6 space-y-2 text-sm">
              <li className="flex gap-2">
                <span className="text-emerald-500">✓</span>
                <span>3 interviews per month</span>
              </li>
              <li className="flex gap-2">
                <span className="text-emerald-500">✓</span>
                <span>Full scored feedback</span>
              </li>
              <li className="flex gap-2">
                <span className="text-emerald-500">✓</span>
                <span>Top 3 coaching themes</span>
              </li>
              <li className="flex gap-2">
                <span className="text-emerald-500">✓</span>
                <span>Progress dashboard</span>
              </li>
            </ul>
            <Link
              href="/signup"
              className="inline-flex rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
            >
              Get started
            </Link>
          </div>
          <div className="rounded-md border border-cyan-500/30 bg-cyan-500/5 p-6">
            <p className="mb-1 text-sm font-medium text-cyan-300">Lifetime</p>
            <p className="mb-4 text-3xl font-semibold">
              Launch via AppSumo
            </p>
            <ul className="mb-6 space-y-2 text-sm">
              <li className="flex gap-2">
                <span className="text-cyan-400">✓</span>
                <span>Unlimited interviews — forever</span>
              </li>
              <li className="flex gap-2">
                <span className="text-cyan-400">✓</span>
                <span>Everything in Free</span>
              </li>
              <li className="flex gap-2">
                <span className="text-cyan-400">✓</span>
                <span>Priority on new features</span>
              </li>
              <li className="flex gap-2">
                <span className="text-cyan-400">✓</span>
                <span>One-time payment, no subscription</span>
              </li>
            </ul>
            <Link
              href="/signup"
              className="inline-flex rounded-md bg-cyan-500 px-4 py-2 text-sm font-semibold text-background hover:opacity-90"
            >
              Get a lifetime code →
            </Link>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="mb-12 rounded-md border border-foreground/10 bg-foreground/5 p-8 text-center sm:p-12">
        <h2 className="text-2xl font-semibold sm:text-3xl">
          Your next interview is the one that counts.
        </h2>
        <p className="mx-auto mt-3 max-w-md text-sm text-foreground/70">
          Practice now so you&apos;re ready when it matters.
        </p>
        <Link
          href="/signup"
          className="mt-6 inline-flex rounded-md bg-foreground px-6 py-3 text-sm font-semibold text-background hover:opacity-90"
        >
          Start practicing free →
        </Link>
      </section>

      {/* Footer */}
      <footer className="flex flex-col gap-4 border-t border-foreground/10 pt-6 text-xs text-foreground/50 sm:flex-row sm:items-center sm:justify-between">
        <Wordmark variant="light" className="h-5 w-auto" />
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
          <Link href="/privacy" className="hover:text-foreground">
            Privacy
          </Link>
          <Link href="/terms" className="hover:text-foreground">
            Terms
          </Link>
          <span>© {new Date().getFullYear()} Career OS</span>
        </div>
      </footer>
    </main>
  );
}
