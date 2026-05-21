import type { Metadata } from "next";
import Link from "next/link";
import { Wordmark } from "@/components/Logo";

export const metadata: Metadata = {
  title: "About · AI Mock Interview Coach",
  description:
    "The story behind AI Mock Interview Coach, built by an independent developer.",
};

export default function AboutPage() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-12">
      <header className="mb-10 flex items-center justify-between">
        <Link href="/" aria-label="AI Mock Interview Coach">
          <Wordmark variant="light" className="h-7 w-auto" />
        </Link>
        <Link
          href="/privacy"
          className="text-xs font-medium text-foreground/70 hover:text-foreground"
        >
          Privacy
        </Link>
      </header>

      <h1 className="mb-8 text-3xl font-semibold">About</h1>

      <div className="space-y-6 text-sm leading-relaxed text-foreground/80">
        <p>
          Hi — I&apos;m Nthabiseng, and I built AI Mock Interview Coach on
          my own.
        </p>

        <p>
          I&apos;m an independent developer. I build practical software with
          AI and ship it straight to the people who use it — no team, no
          investors, no big company behind the curtain. Just one person who
          wanted a better way to prepare for interviews and decided to make
          it.
        </p>

        <p>
          Most interview prep falls into two camps: free question lists that
          never tell you whether your answer was actually good, or human
          coaches at $100+ an hour. I wanted something in between — honest
          scoring, the three things genuinely worth fixing, and your weak
          answers rewritten in your own voice. And I wanted it to cost one
          fair price, not another monthly subscription. That&apos;s why
          Lifetime is $49, once.
        </p>

        <p>
          If it helps you walk into your next interview a little less
          nervous, it did its job. Questions, bugs, or feedback come
          straight to me:{" "}
          <a
            href="mailto:hello@elevra.app"
            className="underline decoration-foreground/40 underline-offset-2 hover:decoration-foreground"
          >
            hello@elevra.app
          </a>
          .
        </p>

        <p className="pt-2 text-foreground">— Nthabiseng Mogatle</p>
      </div>

      <footer className="mt-16 flex flex-col gap-3 border-t border-foreground/10 pt-6 text-xs text-foreground/50 sm:flex-row sm:items-center sm:justify-between">
        <Link href="/" aria-label="AI Mock Interview Coach">
          <Wordmark variant="light" className="h-5 w-auto" />
        </Link>
        <div className="flex gap-4">
          <Link href="/about" className="hover:text-foreground">
            About
          </Link>
          <a
            href="mailto:hello@elevra.app"
            className="hover:text-foreground"
          >
            Support
          </a>
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
