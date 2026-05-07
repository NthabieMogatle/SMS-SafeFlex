import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) redirect("/interview");

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-8 px-6 text-center">
      <div className="space-y-3">
        <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
          Career OS
        </h1>
        <p className="text-lg text-foreground/70">
          Practice mock interviews with an AI coach. Get scored answers,
          targeted feedback, and rewritten responses.
        </p>
      </div>
      <div className="flex gap-3">
        <Link
          href="/signup"
          className="rounded-md bg-foreground px-5 py-2.5 text-sm font-medium text-background hover:opacity-90"
        >
          Get started
        </Link>
        <Link
          href="/login"
          className="rounded-md border border-foreground/20 px-5 py-2.5 text-sm font-medium hover:bg-foreground/5"
        >
          Log in
        </Link>
      </div>
    </main>
  );
}
