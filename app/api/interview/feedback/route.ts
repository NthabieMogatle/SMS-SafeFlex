import { NextResponse } from "next/server";
import { z } from "zod";
import { anthropic, CLAUDE_MODEL } from "@/lib/anthropic";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const RequestSchema = z.object({
  role: z.string().min(1),
  industry: z.string().min(1),
  experienceLevel: z.enum(["entry", "mid", "senior"]),
  answers: z
    .array(
      z.object({
        question: z.string().min(1),
        answer: z.string(),
      }),
    )
    .min(1),
});

type FeedbackItem = {
  question: string;
  score: number;
  strengths: string[];
  weaknesses: string[];
  rewrite: string;
};

export async function POST(req: Request) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const parsed = RequestSchema.safeParse(await req.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }
  const { role, industry, experienceLevel, answers } = parsed.data;

  const system =
    'You are an expert interview coach. Score each answer 0-10, list strengths and weaknesses, and provide a rewritten stronger version. Reply with ONLY JSON of the form {"items":[{"question":string,"score":number,"strengths":string[],"weaknesses":string[],"rewrite":string}]}. No prose, no code fences. The items array must have exactly one entry per Q/A pair below, in order.';

  const userPrompt = `Candidate: ${experienceLevel}-level ${role} in ${industry}.\n\nEvaluate each Q/A pair below.\n\n${answers
    .map((a, i) => `Q${i + 1}: ${a.question}\nA${i + 1}: ${a.answer || "(no answer)"}`)
    .join("\n\n")}`;

  let message;
  try {
    message = await anthropic.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      system,
      messages: [
        { role: "user", content: userPrompt },
        { role: "assistant", content: "{" },
      ],
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : String(e) },
      { status: 502 },
    );
  }

  const text = message.content
    .filter((b): b is { type: "text"; text: string } => b.type === "text")
    .map((b) => b.text)
    .join("");

  let result: { items: FeedbackItem[] };
  try {
    result = JSON.parse("{" + text) as { items: FeedbackItem[] };
    if (!Array.isArray(result.items) || result.items.length === 0) {
      throw new Error("Model returned no feedback items.");
    }
  } catch (e) {
    return NextResponse.json(
      {
        error: `Failed to parse model output: ${e instanceof Error ? e.message : String(e)}`,
        raw: text.slice(0, 400),
      },
      { status: 502 },
    );
  }

  const avg =
    result.items.reduce((sum, item) => sum + (Number(item.score) || 0), 0) /
    result.items.length;

  const { error: insertError } = await supabase.from("interviews").insert({
    user_id: user.id,
    questions: answers.map((a) => a.question),
    answers: answers.map((a) => a.answer),
    feedback: result.items,
    score: Number(avg.toFixed(2)),
  });

  if (insertError) {
    return NextResponse.json(
      { error: `Failed to save interview: ${insertError.message}` },
      { status: 500 },
    );
  }

  return NextResponse.json(result);
}
