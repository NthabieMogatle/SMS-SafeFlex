import type { Metadata } from "next";
import Link from "next/link";
import { Wordmark } from "@/components/Logo";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "How Elevra collects, uses, and stores your data.",
};

const UPDATED = "May 8, 2026";

export default function PrivacyPage() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-12">
      <header className="mb-10 flex items-center justify-between">
        <Link href="/" aria-label="Elevra">
          <Wordmark variant="light" className="h-7 w-auto" />
        </Link>
        <Link
          href="/terms"
          className="text-xs font-medium text-foreground/70 hover:text-foreground"
        >
          Terms
        </Link>
      </header>

      <h1 className="mb-2 text-3xl font-semibold">Privacy Policy</h1>
      <p className="mb-8 text-xs text-foreground/50">Last updated {UPDATED}</p>

      <div className="space-y-8 text-sm leading-relaxed text-foreground/80">
        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            What we collect
          </h2>
          <p>
            When you create an Elevra account we store your email address
            and password (hashed) via our authentication provider. When you
            complete an interview we store the role, industry, and experience
            level you entered, the interview questions generated for you,
            your answers, and the AI-generated feedback for that session.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Why we collect it
          </h2>
          <p>
            We use this data to deliver the product: generate interviews
            tailored to your goals, score your answers, and show your
            history and progress over time. We do not sell your data. We do
            not use your interview content to train third-party models.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Where it&apos;s stored
          </h2>
          <ul className="list-disc space-y-1 pl-5">
            <li>
              <strong>Account + interview data</strong> is stored in our
              Supabase Postgres database with row-level security so only
              you can read your own rows.
            </li>
            <li>
              <strong>Interview questions and answers</strong> are sent to
              Anthropic (Claude) for generation and scoring. Anthropic is
              the AI provider that powers our interview coaching. See
              Anthropic&apos;s usage policies for how they handle prompts.
            </li>
            <li>
              <strong>App hosting and logs</strong> run on Vercel. Standard
              request logs (IP, user agent, timestamps) may be retained by
              Vercel for security and operations purposes.
            </li>
          </ul>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Cookies
          </h2>
          <p>
            We use a session cookie set by our authentication provider so
            you stay logged in between visits. We do not use third-party
            advertising cookies.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Your rights
          </h2>
          <p>
            You can delete your account at any time by contacting us — when
            you do, we delete your profile and all associated interviews
            from our database. You can also request a copy of the data we
            hold for you.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Children
          </h2>
          <p>
            Elevra is not intended for children under 16. If you believe
            a child has created an account, contact us and we&apos;ll
            remove it.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Changes to this policy
          </h2>
          <p>
            We may update this policy as the product evolves. Material
            changes will be communicated via email or an in-app notice. The
            &quot;Last updated&quot; date at the top reflects the current
            version.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            Contact
          </h2>
          <p>
            Questions about your data, requests to delete your account, or
            anything else privacy-related — email{" "}
            <a
              href="mailto:hello@elevra.app"
              className="underline decoration-foreground/40 underline-offset-2 hover:decoration-foreground"
            >
              hello@elevra.app
            </a>
            .
          </p>
        </section>

        <p className="rounded-md border border-amber-500/20 bg-amber-500/5 p-3 text-xs text-amber-300/90">
          ⚠️ This is a starting-point policy generated for launch. Have a
          lawyer or a service like Termly / Iubenda review it for your
          specific jurisdiction before relying on it for production.
        </p>
      </div>

      <footer className="mt-16 flex flex-col gap-3 border-t border-foreground/10 pt-6 text-xs text-foreground/50 sm:flex-row sm:items-center sm:justify-between">
        <Link href="/" aria-label="Elevra">
          <Wordmark variant="light" className="h-5 w-auto" />
        </Link>
        <div className="flex gap-4">
          <Link href="/privacy" className="hover:text-foreground">
            Privacy
          </Link>
          <Link href="/terms" className="hover:text-foreground">
            Terms
          </Link>
        </div>
      </footer>
    </main>
  );
}
