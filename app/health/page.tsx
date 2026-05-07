import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type Check = { label: string; ok: boolean; detail?: string };

async function runChecks(): Promise<Check[]> {
  const checks: Check[] = [];

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const anthropic = process.env.ANTHROPIC_API_KEY;

  checks.push({ label: "NEXT_PUBLIC_SUPABASE_URL set", ok: Boolean(url) });
  checks.push({ label: "NEXT_PUBLIC_SUPABASE_ANON_KEY set", ok: Boolean(key) });
  checks.push({ label: "ANTHROPIC_API_KEY set", ok: Boolean(anthropic) });

  if (url && key) {
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from("profiles")
        .select("user_id")
        .limit(1);

      if (!error) {
        checks.push({ label: "profiles table reachable", ok: true });
      } else if (error.code === "42P01") {
        checks.push({
          label: "profiles table reachable",
          ok: false,
          detail: "Table missing — run supabase/schema.sql in the SQL Editor.",
        });
      } else {
        checks.push({
          label: "profiles table reachable",
          ok: false,
          detail: `${error.code ?? ""} ${error.message}`.trim(),
        });
      }

      const { error: iErr } = await supabase
        .from("interviews")
        .select("id")
        .limit(1);
      if (!iErr) {
        checks.push({ label: "interviews table reachable", ok: true });
      } else if (iErr.code === "42P01") {
        checks.push({
          label: "interviews table reachable",
          ok: false,
          detail: "Table missing — run supabase/schema.sql in the SQL Editor.",
        });
      } else {
        checks.push({
          label: "interviews table reachable",
          ok: false,
          detail: `${iErr.code ?? ""} ${iErr.message}`.trim(),
        });
      }
    } catch (e) {
      checks.push({
        label: "Supabase reachable",
        ok: false,
        detail: e instanceof Error ? e.message : String(e),
      });
    }
  }

  return checks;
}

export default async function HealthPage() {
  const checks = await runChecks();
  const allOk = checks.every((c) => c.ok);

  return (
    <main className="mx-auto max-w-xl px-6 py-12">
      <h1 className="mb-1 text-2xl font-semibold">Health check</h1>
      <p
        className={
          "mb-6 text-sm " + (allOk ? "text-emerald-500" : "text-amber-500")
        }
      >
        {allOk ? "All systems go." : "Some checks failed — see below."}
      </p>
      <ul className="space-y-3">
        {checks.map((c) => (
          <li
            key={c.label}
            className="flex flex-col rounded-md border border-foreground/10 p-3"
          >
            <span className="flex items-center gap-2 text-sm font-medium">
              <span
                aria-hidden
                className={
                  "inline-block h-2.5 w-2.5 rounded-full " +
                  (c.ok ? "bg-emerald-500" : "bg-red-500")
                }
              />
              {c.label}
            </span>
            {c.detail && (
              <span className="mt-1 pl-4 text-xs text-foreground/60">
                {c.detail}
              </span>
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}
