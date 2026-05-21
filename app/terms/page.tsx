import type { Metadata } from "next";
import Link from "next/link";
import { Wordmark } from "@/components/Logo";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "The terms governing your use of AI Mock Interview Coach.",
};

const UPDATED = "May 8, 2026";

export default function TermsPage() {
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

      <h1 className="mb-2 text-3xl font-semibold">Terms of Service</h1>
      <p className="mb-8 text-xs text-foreground/50">Last updated {UPDATED}</p>

      <div className="space-y-8 text-sm leading-relaxed text-foreground/80">
        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            1. Acceptance
          </h2>
          <p>
            By creating an account on AI Mock Interview Coach or using
            the service in any way, you agree to these Terms. If you
            don&apos;t agree, please don&apos;t use the service.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            2. Eligibility
          </h2>
          <p>
            You must be at least 16 years old to use AI Mock Interview
            Coach. By signing up you confirm you meet this minimum age
            and that the information you provide is accurate.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            3. The service
          </h2>
          <p>
            AI Mock Interview Coach uses Anthropic&apos;s Claude to
            generate practice interview questions and feedback. The output is
            automated and is for practice and self-improvement only. It is
            not a guarantee of interview success and is not professional
            career advice. Use it as a coaching tool, not a substitute for
            real preparation, mentorship, or professional services.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            4. Your account
          </h2>
          <p>
            You&apos;re responsible for keeping your password secret and
            for all activity that happens under your account. Tell us
            immediately if you think your account has been compromised.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            5. Acceptable use
          </h2>
          <p>You agree not to:</p>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>Use the service for anything illegal.</li>
            <li>
              Attempt to extract, scrape, or reverse-engineer the service
              or the underlying models.
            </li>
            <li>
              Submit content that is hateful, harassing, or otherwise
              violates Anthropic&apos;s usage policies.
            </li>
            <li>
              Share your account credentials or resell access without our
              permission.
            </li>
            <li>
              Probe, scan, or attempt to disrupt the service&apos;s
              infrastructure.
            </li>
          </ul>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            6. Plans, payment, and refunds
          </h2>
          <p>
            AI Mock Interview Coach offers a free tier with usage
            limits and a lifetime tier — a one-time purchase that grants
            unlimited interviews for the life of the service.
          </p>
          <p className="mt-3">
            How to get a refund depends on where you purchased AI Mock
            Interview Coach.
          </p>
          <p className="mt-3">
            <strong>Purchased through our Gumroad checkout:</strong> We
            offer a full refund within 14 days of purchase, no questions
            asked. Email{" "}
            <a
              href="mailto:hello@elevra.app"
              className="underline decoration-foreground/40 underline-offset-2 hover:decoration-foreground"
            >
              hello@elevra.app
            </a>{" "}
            from the address you used at checkout and we&apos;ll take care
            of it. After 14 days, refunds are at our discretion — but if
            the tool isn&apos;t working as described, reach out and
            we&apos;ll make it right.
          </p>
          <p className="mt-3">
            <strong>Purchased through AppSumo:</strong> Refunds are handled
            by AppSumo under their 60-day money-back guarantee. Request
            yours from your AppSumo account (Products → select the tool →
            Refund). Once refunded, your lifetime access code will be
            deactivated.
          </p>
          <p className="mt-3">
            Either way, the fastest fix is usually just emailing{" "}
            <a
              href="mailto:hello@elevra.app"
              className="underline decoration-foreground/40 underline-offset-2 hover:decoration-foreground"
            >
              hello@elevra.app
            </a>{" "}
            first — most refund situations turn out to be something we can
            sort in a few minutes.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            7. Intellectual property
          </h2>
          <p>
            AI Mock Interview Coach, the brand, the design, and the
            underlying code are ours. Your interview answers are yours.
            The AI-generated
            questions and feedback are produced for your use; we
            don&apos;t claim ownership over what Claude generates for
            you, but we don&apos;t guarantee its uniqueness either.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            8. Termination
          </h2>
          <p>
            You may delete your account at any time. We may suspend or
            terminate accounts that violate these Terms. If we shut down
            the service entirely, lifetime-tier customers will be given
            reasonable advance notice.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            9. Disclaimers
          </h2>
          <p>
            The service is provided &quot;as is.&quot; AI-generated
            content can be wrong, biased, or out of date. We don&apos;t
            warrant that the service will be uninterrupted or error-free,
            or that the feedback will accurately predict any real-world
            interview outcome. Use your judgment.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            10. Limitation of liability
          </h2>
          <p>
            To the maximum extent permitted by law, our total liability to
            you for any claim arising out of these Terms or your use of
            the service is limited to the amount you paid us for the
            service in the 12 months before the claim, or USD $50,
            whichever is greater.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            11. Changes
          </h2>
          <p>
            We may update these Terms as the product evolves. Material
            changes will be announced via email or in-app notice. The
            &quot;Last updated&quot; date reflects the current version.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-base font-semibold text-foreground">
            12. Contact
          </h2>
          <p>
            Questions about these Terms — email{" "}
            <a
              href="mailto:hello@elevra.app"
              className="underline decoration-foreground/40 underline-offset-2 hover:decoration-foreground"
            >
              hello@elevra.app
            </a>
            .
          </p>
        </section>
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
