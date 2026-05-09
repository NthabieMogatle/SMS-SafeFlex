"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

type Status =
  | { kind: "checking" }
  | { kind: "ready" }
  | { kind: "no-session" };

export default function ResetPasswordForm() {
  const router = useRouter();
  const [status, setStatus] = useState<Status>({ kind: "checking" });
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    let cancelled = false;
    let resolved = false;

    // The browser client auto-parses access_token from the URL fragment when
    // the user lands here from the reset-password email link. That triggers
    // either a PASSWORD_RECOVERY event (preferred) or a SIGNED_IN event.
    const { data: subscription } = supabase.auth.onAuthStateChange(
      (event) => {
        if (cancelled) return;
        if (event === "PASSWORD_RECOVERY" || event === "SIGNED_IN") {
          resolved = true;
          setStatus({ kind: "ready" });
        }
      },
    );

    // Also poll the current session in case the event already fired before
    // we subscribed (race condition on the first render).
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (cancelled || resolved) return;
      if (session) {
        resolved = true;
        setStatus({ kind: "ready" });
      } else {
        // Give the URL-fragment parsing a brief moment, then fall back to
        // 'no-session' so we can show a helpful message.
        setTimeout(() => {
          if (!cancelled && !resolved) {
            setStatus({ kind: "no-session" });
          }
        }, 1500);
      }
    });

    return () => {
      cancelled = true;
      subscription.subscription.unsubscribe();
    };
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirmPassword) {
      setError("Passwords don't match.");
      return;
    }

    setLoading(true);
    try {
      const supabase = createClient();
      const { error: updateError } = await supabase.auth.updateUser({
        password,
      });
      if (updateError) {
        const msg = updateError.message.toLowerCase();
        if (msg.includes("session") || msg.includes("expired")) {
          setError(
            "Your reset link has expired. Request a new one and try again.",
          );
        } else if (msg.includes("same") || msg.includes("different")) {
          setError(
            "Pick a password that's different from your current one.",
          );
        } else {
          setError("We couldn't update your password. Please try again.");
        }
        setLoading(false);
        return;
      }
      // Sign out so they have to log in fresh with the new password.
      await supabase.auth.signOut();
      router.push("/login?reset=success");
      router.refresh();
    } catch {
      setError(
        "Something went wrong. Check your connection and try again.",
      );
      setLoading(false);
    }
  }

  if (status.kind === "checking") {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center px-6 py-12">
        <div className="flex items-center gap-2 text-sm text-foreground/60">
          <span
            aria-hidden
            className="h-2 w-2 animate-pulse rounded-full bg-cyan-400"
          />
          Verifying your reset link…
        </div>
      </main>
    );
  }

  if (status.kind === "no-session") {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
        <h1 className="mb-3 text-2xl font-semibold">Reset link not valid</h1>
        <p className="mb-6 text-sm text-foreground/70">
          Your password reset link has expired or already been used. Request
          a fresh link and try again.
        </p>
        <div className="flex flex-wrap gap-3">
          <Link
            href="/auth/forgot-password"
            className="rounded-md bg-foreground px-4 py-2.5 text-sm font-medium text-background hover:opacity-90"
          >
            Request a new link
          </Link>
          <Link
            href="/login"
            className="rounded-md border border-foreground/20 px-4 py-2.5 text-sm font-medium hover:bg-foreground/5"
          >
            Back to login
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold">Set a new password</h1>
      <p className="mb-6 text-sm text-foreground/70">
        Pick a password you haven&apos;t used here before.
      </p>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="mb-1 block text-sm font-medium" htmlFor="password">
            New password
          </label>
          <input
            id="password"
            type="password"
            required
            minLength={8}
            autoComplete="new-password"
            autoFocus
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          />
          <p className="mt-1 text-xs text-foreground/50">
            8 characters minimum.
          </p>
        </div>
        <div>
          <label
            className="mb-1 block text-sm font-medium"
            htmlFor="confirm-password"
          >
            Confirm new password
          </label>
          <input
            id="confirm-password"
            type="password"
            required
            minLength={8}
            autoComplete="new-password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          />
        </div>
        {error && <p className="text-sm text-red-500">{error}</p>}
        <button
          type="submit"
          disabled={
            loading ||
            password.length === 0 ||
            confirmPassword.length === 0
          }
          className="w-full rounded-md bg-foreground px-4 py-2.5 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
        >
          {loading ? "Updating password…" : "Update password"}
        </button>
      </form>
    </main>
  );
}
