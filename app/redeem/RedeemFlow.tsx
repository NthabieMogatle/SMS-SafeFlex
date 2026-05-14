"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";

type Status =
  | "checking_auth"
  | "redeeming"
  | "signup"
  | "signin"
  | "signing_up"
  | "signing_in"
  | "success"
  | "error"
  | "manual_required";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function callRedeem(
  code: string,
): Promise<{ ok: true; tier?: string } | { ok: false; error: string }> {
  try {
    const res = await fetch("/api/redeem", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    });
    const data = (await res.json().catch(() => ({}))) as {
      tier?: string;
      error?: string;
    };
    if (!res.ok) {
      return {
        ok: false,
        error:
          data.error ?? "We couldn't redeem that code right now. Please try again.",
      };
    }
    return { ok: true, tier: data.tier };
  } catch {
    return {
      ok: false,
      error: "Something went wrong. Please check your connection.",
    };
  }
}

export default function RedeemFlow({ code }: { code: string }) {
  const router = useRouter();
  const [status, setStatus] = useState<Status>("checking_auth");
  const [error, setError] = useState<string | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [pendingEmail, setPendingEmail] = useState<string | null>(null);
  const attempted = useRef(false);

  const redeemNow = useCallback(async () => {
    setStatus("redeeming");
    setError(null);
    const result = await callRedeem(code);
    if (result.ok) {
      setStatus("success");
    } else {
      setError(result.error);
      setStatus("error");
    }
  }, [code]);

  useEffect(() => {
    if (attempted.current) return;
    attempted.current = true;
    const supabase = createClient();
    (async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (session) {
        await redeemNow();
      } else {
        setStatus("signup");
      }
    })();
  }, [redeemNow]);

  // Auto-redirect to dashboard after success.
  useEffect(() => {
    if (status !== "success") return;
    const t = window.setTimeout(() => {
      router.push("/dashboard");
      router.refresh();
    }, 4000);
    return () => window.clearTimeout(t);
  }, [status, router]);

  function validateCredentials(): string | null {
    if (!EMAIL_PATTERN.test(email)) return "Enter a valid email address.";
    if (password.length < 8) return "Password must be at least 8 characters.";
    return null;
  }

  async function handleSignup(e: React.FormEvent) {
    e.preventDefault();
    const v = validateCredentials();
    if (v) {
      setError(v);
      return;
    }
    setError(null);
    setStatus("signing_up");
    try {
      const supabase = createClient();
      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
      });
      if (signUpError) {
        const msg = signUpError.message.toLowerCase().includes("already")
          ? "An account with that email already exists. Use “Sign in” instead."
          : "We couldn't create your account. Please try again.";
        setError(msg);
        setStatus("signup");
        return;
      }
      if (data.session) {
        await redeemNow();
        return;
      }
      // No session — Supabase is holding the user for email confirmation.
      // Try a password sign-in as a fallback (works if Confirm email is OFF
      // or if the project allows pre-confirmation sign-in).
      const { data: signInData, error: signInError } =
        await supabase.auth.signInWithPassword({ email, password });
      if (signInError || !signInData.session) {
        setPendingEmail(email);
        setStatus("manual_required");
        return;
      }
      await redeemNow();
    } catch {
      setError("Something went wrong. Please check your connection.");
      setStatus("signup");
    }
  }

  async function handleSignin(e: React.FormEvent) {
    e.preventDefault();
    const v = validateCredentials();
    if (v) {
      setError(v);
      return;
    }
    setError(null);
    setStatus("signing_in");
    try {
      const supabase = createClient();
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (signInError) {
        const msg = signInError.message.toLowerCase().includes("invalid")
          ? "Email or password is incorrect."
          : "We couldn't sign you in. Please try again.";
        setError(msg);
        setStatus("signin");
        return;
      }
      await redeemNow();
    } catch {
      setError("Something went wrong. Please check your connection.");
      setStatus("signin");
    }
  }

  const isSignupMode = status === "signup" || status === "signing_up";
  const isSigninMode = status === "signin" || status === "signing_in";
  const isAuthFormBusy = status === "signing_up" || status === "signing_in";

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <header className="mb-6">
        <p className="mb-2 text-xs font-medium uppercase tracking-wider text-cyan-300">
          Elevra · AppSumo
        </p>
        <h1 className="text-2xl font-semibold sm:text-3xl">
          Redeem your lifetime code
        </h1>
        <p className="mt-2 text-sm text-foreground/70">
          One-time redemption — unlimited mock interviews, forever.
        </p>
      </header>

      <div className="mb-6 rounded-md border border-cyan-500/30 bg-cyan-500/5 p-4">
        <p className="mb-1 text-xs font-medium uppercase tracking-wide text-cyan-300">
          Your code
        </p>
        <p className="break-all font-mono text-base tracking-wider">{code}</p>
        <p className="mt-2 text-xs text-foreground/60">
          Check that this matches the code AppSumo gave you.
        </p>
      </div>

      {status === "checking_auth" && (
        <p className="text-sm text-foreground/70">Checking your account…</p>
      )}

      {status === "redeeming" && (
        <div
          className="flex items-center gap-3 text-sm text-foreground/80"
          role="status"
          aria-live="polite"
        >
          <span
            aria-hidden
            className="h-4 w-4 animate-spin rounded-full border-2 border-foreground/40 border-t-transparent"
          />
          Activating your lifetime access…
        </div>
      )}

      {(isSignupMode || isSigninMode) && (
        <form
          onSubmit={isSignupMode ? handleSignup : handleSignin}
          className="space-y-4"
        >
          <p className="text-sm text-foreground/70">
            {isSignupMode
              ? "Create your account to claim this code. We'll redeem it as soon as you sign up."
              : "Sign in to claim this code on your existing account."}
          </p>
          <div>
            <label className="mb-1 block text-sm font-medium" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={8}
              autoComplete={isSignupMode ? "new-password" : "current-password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
            />
            {isSignupMode && (
              <p className="mt-1 text-xs text-foreground/50">
                8 characters minimum.
              </p>
            )}
          </div>
          {error && <p className="text-sm text-red-500">{error}</p>}
          <button
            type="submit"
            disabled={isAuthFormBusy}
            className="w-full rounded-md bg-cyan-500 px-4 py-2.5 text-sm font-semibold text-background hover:opacity-90 disabled:opacity-50"
          >
            {isSignupMode
              ? status === "signing_up"
                ? "Creating account…"
                : "Sign up & redeem"
              : status === "signing_in"
                ? "Signing in…"
                : "Sign in & redeem"}
          </button>
          <p className="text-sm text-foreground/60">
            {isSignupMode ? (
              <>
                Already have an account?{" "}
                <button
                  type="button"
                  onClick={() => {
                    setError(null);
                    setStatus("signin");
                  }}
                  className="underline"
                >
                  Sign in
                </button>
              </>
            ) : (
              <>
                Need an account?{" "}
                <button
                  type="button"
                  onClick={() => {
                    setError(null);
                    setStatus("signup");
                  }}
                  className="underline"
                >
                  Sign up
                </button>
              </>
            )}
          </p>
        </form>
      )}

      {status === "success" && (
        <div className="rounded-md border border-emerald-500/30 bg-emerald-500/10 p-5">
          <p className="mb-1 text-base font-semibold text-emerald-300">
            🎉 You&apos;re on Lifetime. Welcome to Elevra.
          </p>
          <p className="mb-4 text-sm text-foreground/80">
            Unlimited mock interviews, full feedback, and your full session
            history — yours forever.
          </p>
          <Link
            href="/dashboard"
            className="inline-flex rounded-md bg-foreground px-4 py-2 text-sm font-semibold text-background hover:opacity-90"
          >
            Go to Dashboard →
          </Link>
          <p className="mt-3 text-xs text-foreground/50">
            Redirecting you automatically in a few seconds…
          </p>
        </div>
      )}

      {status === "error" && (
        <div className="rounded-md border border-red-500/30 bg-red-500/10 p-5">
          <p className="mb-2 text-sm font-semibold text-red-300">
            We couldn&apos;t redeem your code.
          </p>
          <p className="mb-4 break-words text-sm text-foreground/80">
            {error ?? "Something went wrong."}
          </p>
          <div className="flex flex-wrap gap-3">
            <Link
              href="/account"
              className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
            >
              Paste code manually
            </Link>
            <a
              href="mailto:hello@elevra.app"
              className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
            >
              Contact support
            </a>
          </div>
        </div>
      )}

      {status === "manual_required" && (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-5">
          <p className="mb-2 text-sm font-semibold text-amber-300">
            Confirm your email to finish redeeming.
          </p>
          <p className="mb-3 text-sm text-foreground/80">
            We created your account{pendingEmail ? ` for ${pendingEmail}` : ""}.
            Check your inbox for a confirmation email, then return to{" "}
            <strong>elevra.app/account</strong> and paste this code:
          </p>
          <div className="mb-4 rounded-md border border-foreground/20 bg-background/40 p-3">
            <p className="break-all font-mono text-base tracking-wider">
              {code}
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              href="/account"
              className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
            >
              Go to account
            </Link>
            <a
              href="mailto:hello@elevra.app"
              className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
            >
              Contact support
            </a>
          </div>
        </div>
      )}
    </main>
  );
}
