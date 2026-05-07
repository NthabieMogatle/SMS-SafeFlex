"use client";

import { useEffect, useState } from "react";
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

export default function InterviewClient({ profile }: { profile: Profile }) {
  const router = useRouter();
  const [questions, setQuestions] = useState<string[] | null>(null);
  const [answers, setAnswers] = useState<string[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [currentAnswer, setCurrentAnswer] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function fetchQuestions() {
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
          const body = await res.text();
          throw new Error(`(${res.status}) ${body}`);
        }
        const data = (await res.json()) as { questions: string[] };
        if (cancelled) return;
        setQuestions(data.questions);
        setAnswers(new Array(data.questions.length).fill(""));
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    fetchQuestions();
    return () => {
      cancelled = true;
    };
  }, [profile]);

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

  async function handleSubmit() {
    if (!questions) return;
    setSubmitting(true);
    setError(null);
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
            const body = await res.text();
            throw new Error(`Q${i + 1} scoring failed: (${res.status}) ${body}`);
          }
          return (await res.json()) as ScoreResult;
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

      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not signed in.");

      const { error: insertError } = await supabase.from("interviews").insert({
        user_id: user.id,
        questions,
        answers: finalAnswers,
        feedback: items,
        score: Number(avg.toFixed(2)),
      });
      if (insertError) {
        throw new Error(`Saving interview failed: ${insertError.message}`);
      }

      router.push("/feedback");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
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

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col px-6 py-12">
      <p className="mb-2 text-sm text-foreground/60">
        Question {currentIndex + 1} of {questions.length}
      </p>
      <h1 className="mb-6 text-xl font-semibold">{questions[currentIndex]}</h1>
      <textarea
        value={currentAnswer}
        onChange={(e) => setCurrentAnswer(e.target.value)}
        rows={8}
        placeholder="Type your answer…"
        className="w-full rounded-md border border-foreground/20 bg-transparent p-3"
      />
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
            disabled={submitting || !currentAnswer.trim()}
            className="ml-auto rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
          >
            {submitting ? "Scoring…" : "Submit for feedback"}
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
