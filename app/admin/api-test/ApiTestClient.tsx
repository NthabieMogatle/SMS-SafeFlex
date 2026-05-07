"use client";

import { useState } from "react";

type Json = unknown;

function ResultPanel({
  loading,
  result,
}: {
  loading: boolean;
  result: { ok: boolean; status?: number; body: Json } | null;
}) {
  if (loading) {
    return (
      <p className="mt-3 text-xs text-foreground/60">Calling endpoint…</p>
    );
  }
  if (!result) return null;
  return (
    <div className="mt-3">
      <p
        className={
          "text-xs font-medium " +
          (result.ok ? "text-emerald-500" : "text-red-500")
        }
      >
        {result.ok ? "OK" : "ERROR"}
        {result.status !== undefined && ` (HTTP ${result.status})`}
      </p>
      <pre className="mt-1 max-h-96 overflow-auto whitespace-pre-wrap break-all rounded-md border border-foreground/10 bg-foreground/5 p-3 font-mono text-xs">
        {JSON.stringify(result.body, null, 2)}
      </pre>
    </div>
  );
}

async function callJson(url: string, body: unknown) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  let parsed: Json;
  try {
    parsed = await res.json();
  } catch {
    parsed = { error: "Response was not valid JSON" };
  }
  return { ok: res.ok, status: res.status, body: parsed };
}

export default function ApiTestClient({
  signedIn,
  userEmail,
}: {
  signedIn: boolean;
  userEmail: string | null;
}) {
  // generate-questions
  const [role, setRole] = useState("Product Manager");
  const [industry, setIndustry] = useState("Fintech");
  const [experienceLevel, setExperienceLevel] = useState<
    "entry" | "mid" | "senior"
  >("mid");
  const [qLoading, setQLoading] = useState(false);
  const [qResult, setQResult] = useState<{
    ok: boolean;
    status?: number;
    body: Json;
  } | null>(null);

  // score-answer
  const [question, setQuestion] = useState(
    "Tell me about a time you led a project under a tight deadline.",
  );
  const [answer, setAnswer] = useState(
    "I led a 4-person team to ship a payments feature in 3 weeks by scoping aggressively and pairing daily.",
  );
  const [sLoading, setSLoading] = useState(false);
  const [sResult, setSResult] = useState<{
    ok: boolean;
    status?: number;
    body: Json;
  } | null>(null);

  async function runGenerate() {
    setQLoading(true);
    setQResult(null);
    setQResult(
      await callJson("/api/generate-questions", {
        role,
        industry,
        experienceLevel,
      }),
    );
    setQLoading(false);
  }

  async function runScore() {
    setSLoading(true);
    setSResult(null);
    setSResult(await callJson("/api/score-answer", { question, answer }));
    setSLoading(false);
  }

  return (
    <main className="mx-auto max-w-2xl px-6 py-10">
      <header className="mb-8">
        <h1 className="text-2xl font-semibold">API test</h1>
        <p className="mt-1 text-xs text-foreground/60">
          Hidden dev page. Manually exercise the Claude routes.
        </p>
        {signedIn ? (
          <p className="mt-2 text-xs text-emerald-500">
            Signed in as {userEmail}. API calls will be authorized.
          </p>
        ) : (
          <p className="mt-2 text-xs text-amber-500">
            Not signed in — both endpoints will return 401. Log in first, then
            return here.
          </p>
        )}
      </header>

      <section className="mb-10 rounded-md border border-foreground/10 p-4">
        <h2 className="mb-1 text-base font-semibold">POST /api/generate-questions</h2>
        <p className="mb-4 text-xs text-foreground/60">
          Body: {"{ role, industry, experienceLevel }"}
        </p>

        <div className="space-y-3">
          <div>
            <label
              className="mb-1 block text-xs font-medium"
              htmlFor="role"
            >
              role
            </label>
            <input
              id="role"
              type="text"
              value={role}
              onChange={(e) => setRole(e.target.value)}
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label
              className="mb-1 block text-xs font-medium"
              htmlFor="industry"
            >
              industry
            </label>
            <input
              id="industry"
              type="text"
              value={industry}
              onChange={(e) => setIndustry(e.target.value)}
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label
              className="mb-1 block text-xs font-medium"
              htmlFor="exp"
            >
              experienceLevel
            </label>
            <select
              id="exp"
              value={experienceLevel}
              onChange={(e) =>
                setExperienceLevel(
                  e.target.value as "entry" | "mid" | "senior",
                )
              }
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2 text-sm"
            >
              <option value="entry">entry</option>
              <option value="mid">mid</option>
              <option value="senior">senior</option>
            </select>
          </div>
        </div>

        <button
          type="button"
          onClick={runGenerate}
          disabled={qLoading}
          className="mt-4 rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
        >
          {qLoading ? "Calling…" : "Test endpoint"}
        </button>
        <ResultPanel loading={qLoading} result={qResult} />
      </section>

      <section className="rounded-md border border-foreground/10 p-4">
        <h2 className="mb-1 text-base font-semibold">POST /api/score-answer</h2>
        <p className="mb-4 text-xs text-foreground/60">
          Body: {"{ question, answer }"}
        </p>

        <div className="space-y-3">
          <div>
            <label
              className="mb-1 block text-xs font-medium"
              htmlFor="q"
            >
              question
            </label>
            <textarea
              id="q"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              rows={2}
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label
              className="mb-1 block text-xs font-medium"
              htmlFor="a"
            >
              answer
            </label>
            <textarea
              id="a"
              value={answer}
              onChange={(e) => setAnswer(e.target.value)}
              rows={5}
              className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2 text-sm"
            />
          </div>
        </div>

        <button
          type="button"
          onClick={runScore}
          disabled={sLoading}
          className="mt-4 rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
        >
          {sLoading ? "Calling…" : "Test endpoint"}
        </button>
        <ResultPanel loading={sLoading} result={sResult} />
      </section>
    </main>
  );
}
