"use client";

import Link from "next/link";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

function buildRedirectTo(): string {
  const envUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  // Prefer the configured site URL in production. Fall back to the current
  // origin in dev / preview so reset links work without env vars.
  const baseRaw =
    envUrl && envUrl.length > 0
      ? envUrl
      : typeof window !== "undefined"
        ? window.location.origin
        : "https://elevra.app";
  const withProtocol = /^https?:\/\//i.test(baseRaw)
    ? baseRaw
    : `https://${baseRaw}`;
  return `${withProtocol.replace(/\/$/, "")}/auth/reset-password`;
}

export default function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const supabase = createClient();
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(
        email.trim(),
        { redirectTo: buildRedirectTo() },
      );

      // Supabase intentionally doesn't reveal whether the email exists, to
      // prevent enumeration. We always show the same success state unless
      // the failure is clearly client-side (network / rate limit).
      if (resetError) {
        const msg = resetError.message.toLowerCase();
        if (msg.includes("rate") || msg.includes("too many")) {
          setError(
            "Too many requests. Please wait a minute before trying again.",
          );
          setLoading(false);
          return;
        }
        if (msg.includes("network") || msg.includes("fetch")) {
          setError(
            "We couldn't reach the server. Check your connection and try again.",
          );
          setLoading(false);
          return;
        }
        // Otherwise fall through to the generic success state.
      }

      setSubmitted(true);
      setLoading(false);
    } catch {
      setError(
        "Something went wrong. Check your connection and try again.",
      );
      setLoading(false);
    }
  }

  if (submitted) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
        <h1 className="mb-3 text-2xl font-semibold">Check your email</h1>
        <p className="mb-6 text-sm text-foreground/70">
          If an account exists for{" "}
          <span className="font-medium text-foreground">{email}</span>,
          we&apos;ve sent a password reset link. Click the link to set a new
          password. The link expires in about an hour.
        </p>
        <p className="mb-8 text-xs text-foreground/50">
          Didn&apos;t get it? Check your spam folder, or{" "}
          <button
            type="button"
            onClick={() => {
              setSubmitted(false);
              setError(null);
            }}
            className="text-cyan-400 underline-offset-2 hover:text-cyan-300 hover:underline"
          >
            try a different email
          </button>
          .
        </p>
        <Link
          href="/login"
          className="inline-flex justify-center rounded-md border border-foreground/20 px-4 py-2.5 text-sm font-medium hover:bg-foreground/5"
        >
          ← Back to login
        </Link>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold">Forgot your password?</h1>
      <p className="mb-6 text-sm text-foreground/70">
        Enter the email you signed up with and we&apos;ll send you a link to
        set a new one.
      </p>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="mb-1 block text-sm font-medium" htmlFor="email">
            Email
          </label>
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            autoFocus
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          />
        </div>
        {error && <p className="text-sm text-red-500">{error}</p>}
        <button
          type="submit"
          disabled={loading || email.trim().length === 0}
          className="w-full rounded-md bg-foreground px-4 py-2.5 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
        >
          {loading ? "Sending reset link…" : "Send reset link"}
        </button>
      </form>
      <p className="mt-4 text-sm text-foreground/60">
        Remembered it?{" "}
        <Link href="/login" className="underline">
          Back to login
        </Link>
      </p>
    </main>
  );
}
