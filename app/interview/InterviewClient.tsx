"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Profile = {
  target_role: string;
  industry: string;
  experience_level: "entry" | "mid" | "senior";
};

type ScoreResult = {
  score: number;
  strengths: string[];
  weaknesses: string[];
  rewrite: string;
};

const DRAFT_KEY = "career-os:draft:v1";
const DRAFT_MAX_AGE_MS = 24 * 60 * 60 * 1000;

type Draft = {
  questions: string[];
  answers: string[];
  currentIndex: number;
  fingerprint: string;
  savedAt: number;
};

function fingerprintOf(p: Profile) {
  return `${p.target_role}|${p.industry}|${p.experience_level}`;
}

function loadDraft(profile: Profile): Draft | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(DRAFT_KEY);
    if (!raw) return null;
    const draft = JSON.parse(raw) as Draft;
    if (draft.fingerprint !== fingerprintOf(profile)) return null;
    if (Date.now() - draft.savedAt > DRAFT_MAX_AGE_MS) return null;
    if (!Array.isArray(draft.questions) || draft.questions.length === 0) {
      return null;
    }
    return draft;
  } catch {
    return null;
  }
}

function saveDraft(d: Draft) {
  try {
    window.localStorage.setItem(DRAFT_KEY, JSON.stringify(d));
  } catch {
    // ignore quota errors
  }
}

function clearDraft() {
  try {
    window.localStorage.removeItem(DRAFT_KEY);
  } catch {
    // ignore
  }
}

export default function InterviewClient({
  profile,
  startFresh,
}: {
  profile: Profile;
  startFresh: boolean;
}) {
  const router = useRouter();

  const [questions, setQuestions] = useState<string[] | null>(null);
  const [answers, setAnswers] = useState<string[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [currentAnswer, setCurrentAnswer] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [scoredCount, setScoredCount] = useState(0);
  const [submitStage, setSubmitStage] = useState<"scoring" | "summarizing" | "saving">("scoring");
  const [restoredFromDraft, setRestoredFromDraft] = useState(false);

  const initialized = useRef(false);

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;

    if (startFresh) {
      clearDraft();
      // Strip the ?fresh=1 from the URL so refresh doesn't re-fetch.
      window.history.replaceState({}, "", "/interview");
    } else {
      const draft = loadDraft(profile);
      if (draft) {
        setQuestions(draft.questions);
        setAnswers(draft.answers);
        setCurrentIndex(draft.currentIndex);
        setCurrentAnswer(draft.answers[draft.currentIndex] ?? "");
        setRestoredFromDraft(true);
        setLoading(false);
        return;
      }
    }

    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/generate-questions", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            role: profile.target_role,
            industry: profile.industry,
            experienceLevel: profile.experience_level,
          }),
        });
        if (!res.ok) {
          throw new Error(
            "We couldn't generate your interview right now. Please try again.",
          );
        }
        const data = (await res.json()) as { questions: string[] };
        if (cancelled) return;
        setQuestions(data.questions);
        setAnswers(new Array(data.questions.length).fill(""));
        saveDraft({
          questions: data.questions,
          answers: new Array(data.questions.length).fill(""),
          currentIndex: 0,
          fingerprint: fingerprintOf(profile),
          savedAt: Date.now(),
        });
      } catch (e) {
        if (cancelled) return;
        setError(
          e instanceof Error
            ? e.message
            : "Something went wrong. Please try again.",
        );
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [profile, startFresh]);

  // Persist current state to localStorage whenever it changes.
  useEffect(() => {
    if (!questions || submitting) return;
    const next = [...answers];
    next[currentIndex] = currentAnswer;
    saveDraft({
      questions,
      answers: next,
      currentIndex,
      fingerprint: fingerprintOf(profile),
      savedAt: Date.now(),
    });
  }, [questions, answers, currentAnswer, currentIndex, profile, submitting]);

  function handleNext() {
    if (!questions) return;
    const newAnswers = [...answers];
    newAnswers[currentIndex] = currentAnswer;
    setAnswers(newAnswers);
    if (currentIndex < questions.length - 1) {
      const nextIdx = currentIndex + 1;
      setCurrentIndex(nextIdx);
      setCurrentAnswer(newAnswers[nextIdx] ?? "");
    }
  }

  function handlePrevious() {
    if (currentIndex === 0) return;
    const newAnswers = [...answers];
    newAnswers[currentIndex] = currentAnswer;
    setAnswers(newAnswers);
    const prevIdx = currentIndex - 1;
    setCurrentIndex(prevIdx);
    setCurrentAnswer(newAnswers[prevIdx] ?? "");
  }

  function handleDiscardAndStartOver() {
    if (
      !window.confirm(
        "Discard your current draft and start a new interview? Your unsaved answers will be lost.",
      )
    ) {
      return;
    }
    clearDraft();
    window.location.href = "/interview?fresh=1";
  }

  async function handleSubmit() {
    if (!questions) return;
    setSubmitting(true);
    setError(null);
    setScoredCount(0);
    setSubmitStage("scoring");

    const finalAnswers = [...answers];
    finalAnswers[currentIndex] = currentAnswer;

    try {
      const scoreResults = await Promise.all(
        questions.map(async (q, i) => {
          const res = await fetch("/api/score-answer", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ question: q, answer: finalAnswers[i] ?? "" }),
          });
          if (!res.ok) {
            throw new Error(
              "We couldn't score one of your answers. Please try submitting again.",
            );
          }
          const data = (await res.json()) as ScoreResult;
          setScoredCount((c) => c + 1);
          return data;
        }),
      );

      const items = questions.map((q, i) => ({
        question: q,
        score: Number(scoreResults[i].score) || 0,
        strengths: scoreResults[i].strengths ?? [],
        weaknesses: scoreResults[i].weaknesses ?? [],
        rewrite: scoreResults[i].rewrite ?? "",
      }));

      const avg =
        items.reduce((sum, it) => sum + it.score, 0) / items.length;

      // Best-effort: ask Claude to summarize the top 3 coaching themes
      // across all weaknesses. If this fails, we still save the interview
      // without themes.
      setSubmitStage("summarizing");
      let themes: string[] = [];
      try {
        const themesRes = await fetch("/api/summarize-themes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            weaknesses: items.map((it) => it.weaknesses),
          }),
        });
        if (themesRes.ok) {
          const data = (await themesRes.json()) as { themes?: string[] };
          themes = Array.isArray(data.themes) ? data.themes : [];
        }
      } catch {
        // Swallow; themes are non-essential.
      }

      setSubmitStage("saving");
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Your session expired. Please log in again.");

      const { error: insertError } = await supabase.from("interviews").insert({
        user_id: user.id,
        role: profile.target_role,
        industry: profile.industry,
        experience_level: profile.experience_level,
        questions,
        answers: finalAnswers,
        feedback: items,
        themes,
        score: Number(avg.toFixed(2)),
      });
      if (insertError) {
        throw new Error(
          "We couldn't save your interview. Please try submitting again.",
        );
      }

      clearDraft();
      router.push("/feedback");
      router.refresh();
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : "Something went wrong. Please try again.",
      );
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center px-6 py-12">
        <p className="text-foreground/70">Generating your interview…</p>
      </main>
    );
  }

  if (error && !questions) {
    return (
      <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-3 px-6 py-12 text-center">
        <h1 className="text-xl font-semibold">
          Couldn&apos;t generate questions
        </h1>
        <p className="break-all text-sm text-red-500">{error}</p>
        <p className="text-xs text-foreground/60">
          Most likely cause: ANTHROPIC_API_KEY in Vercel is missing or invalid.
        </p>
      </main>
    );
  }

  if (!questions) return null;

  const isLast = currentIndex === questions.length - 1;
  const total = questions.length;

  if (submitting) {
    const pct =
      submitStage === "scoring"
        ? Math.round((scoredCount / total) * 80)
        : submitStage === "summarizing"
          ? 90
          : 100;
    const stageLabel =
      submitStage === "scoring"
        ? scoredCount === total
          ? "Wrapping up…"
          : `Scoring answer ${Math.min(scoredCount + 1, total)} of ${total}`
        : submitStage === "summarizing"
          ? "Identifying coaching themes…"
          : "Saving your results…";
    return (
      <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-4 px-6 py-12 text-center">
        <h1 className="text-xl font-semibold">Scoring your interview…</h1>
        <p className="text-sm text-foreground/70">{stageLabel}</p>
        <div
          className="h-2 w-full max-w-xs overflow-hidden rounded-full bg-foreground/10"
          role="progressbar"
          aria-valuenow={pct}
          aria-valuemin={0}
          aria-valuemax={100}
        >
          <div
            className="h-full bg-emerald-500 transition-all duration-300"
            style={{ width: `${pct}%` }}
          />
        </div>
        {error && <p className="break-all text-sm text-red-500">{error}</p>}
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col px-6 py-8">
      <div className="mb-4 flex items-center justify-between">
        <p className="text-sm text-foreground/60">
          Question {currentIndex + 1} of {total}
          {restoredFromDraft && (
            <span
              className="ml-2 rounded-full bg-foreground/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-foreground/70"
              title="Resumed from your saved draft"
            >
              Draft
            </span>
          )}
        </p>
        <button
          type="button"
          onClick={handleDiscardAndStartOver}
          className="text-xs text-foreground/60 underline-offset-2 hover:text-foreground hover:underline"
        >
          Start over
        </button>
      </div>

      <div className="mb-4 h-1 w-full overflow-hidden rounded-full bg-foreground/10">
        <div
          className="h-full bg-foreground transition-all duration-300"
          style={{ width: `${((currentIndex + 1) / total) * 100}%` }}
        />
      </div>

      <h1 className="mb-6 text-xl font-semibold">{questions[currentIndex]}</h1>
      <textarea
        value={currentAnswer}
        onChange={(e) => setCurrentAnswer(e.target.value)}
        rows={8}
        placeholder="Type your answer…"
        className="w-full rounded-md border border-foreground/20 bg-transparent p-3"
      />
      <p className="mt-1 text-[10px] text-foreground/40">
        Auto-saved as you type.
      </p>
      <div className="mt-4 flex gap-3">
        <button
          type="button"
          onClick={handlePrevious}
          disabled={currentIndex === 0}
          className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5 disabled:opacity-50"
        >
          Previous
        </button>
        {isLast ? (
          <button
            type="button"
            onClick={handleSubmit}
            disabled={!currentAnswer.trim()}
            className="ml-auto rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
          >
            Submit for feedback
          </button>
        ) : (
          <button
            type="button"
            onClick={handleNext}
            disabled={!currentAnswer.trim()}
            className="ml-auto rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
          >
            Next
          </button>
        )}
      </div>
      {error && (
        <p className="mt-3 break-all text-sm text-red-500">{error}</p>
      )}
    </main>
  );
}
