"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import PasswordInput from "@/components/ui/password-input";

export default function SignupForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [confirmationSent, setConfirmationSent] = useState(false);
  const [resending, setResending] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setLoading(true);
    try {
      const supabase = createClient();
      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
      });
      if (signUpError) {
        const msg = signUpError.message.toLowerCase().includes("already")
          ? "An account with that email already exists. Try logging in."
          : "We couldn't create your account. Please try again.";
        setError(msg);
        setLoading(false);
        return;
      }
      if (!data.session) {
        setInfo(
          "Account created. Check your email for a confirmation link, then log in.",
        );
        setConfirmationSent(true);
        setLoading(false);
        return;
      }
      router.push("/setup");
      router.refresh();
    } catch {
      setError(
        "Something went wrong. Please check your connection and try again.",
      );
      setLoading(false);
    }
  }

  async function handleResend() {
    if (!email) return;
    setResending(true);
    setError(null);
    try {
      const supabase = createClient();
      const { error: resendError } = await supabase.auth.resend({
        type: "signup",
        email,
      });
      if (resendError) {
        setError(
          "We couldn't resend the confirmation email. Please try again in a minute.",
        );
      } else {
        setInfo(
          `Confirmation email re-sent to ${email}. Check your inbox (and spam folder).`,
        );
      }
    } catch {
      setError("Something went wrong. Please check your connection.");
    } finally {
      setResending(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <h1 className="mb-6 text-2xl font-semibold">Create your account</h1>
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
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          />
        </div>
        <div>
          <label className="mb-1 block text-sm font-medium" htmlFor="password">
            Password
          </label>
          <PasswordInput
            id="password"
            required
            minLength={8}
            autoComplete="new-password"
            value={password}
            onChange={setPassword}
          />
          <p className="mt-1 text-xs text-foreground/50">
            8 characters minimum.
          </p>
        </div>
        {error && <p className="text-sm text-red-500">{error}</p>}
        {info && <p className="text-sm text-emerald-500">{info}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-md bg-foreground px-4 py-2.5 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
        >
          {loading ? "Creating account…" : "Sign up"}
        </button>
      </form>
      {confirmationSent && (
        <div className="mt-4 rounded-md border border-foreground/10 p-3 text-xs">
          <p className="mb-2 text-foreground/70">
            Didn&apos;t get the email? Check your spam folder, or…
          </p>
          <button
            type="button"
            onClick={handleResend}
            disabled={resending}
            className="rounded-md border border-foreground/20 px-3 py-1.5 text-xs font-medium hover:bg-foreground/5 disabled:opacity-50"
          >
            {resending ? "Resending…" : "Resend confirmation email"}
          </button>
        </div>
      )}
      <p className="mt-4 text-sm text-foreground/60">
        Already have an account?{" "}
        <Link href="/login" className="underline">
          Log in
        </Link>
      </p>
    </main>
  );
}
