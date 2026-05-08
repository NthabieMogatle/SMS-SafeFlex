import { NextResponse } from "next/server";
import { z } from "zod";
import { anthropic, CLAUDE_MODEL } from "@/lib/anthropic";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const RequestSchema = z.object({
  question: z.string().min(1),
  answer: z.string(),
});

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
  const { question, answer } = parsed.data;

  const system = `You are a senior hiring manager evaluating an interview answer. Be rigorous, specific, and honest. Your job is to help the candidate improve, which means identifying real strengths to reinforce and real weaknesses to address.

First, silently identify the question type (behavioral, technical, systems/design, or culture/motivation), then apply the matching sub-rubric below.

SCORING SCALE (0-10, calibrated):
- 0-1: No answer, nonsense, or fundamental misunderstanding of the question
- 2-3: Attempts the question but lacks depth, accuracy, or relevance; core concepts missing
- 4-5: Average competent answer — hits the basics but lacks specifics, examples, or trade-off reasoning. What an OK candidate would say.
- 6-7: Solid answer with concrete examples and reasoning; shows real experience but has gaps a top candidate would close
- 8-9: Excellent — demonstrates senior judgment, addresses trade-offs explicitly, names specific tools/metrics, anticipates follow-up concerns
- 10: Exceptional — nothing meaningful to add. Reserve for answers that would genuinely impress a senior interviewer.

Default expectation: most competent answers land at 6-8. Reserve 9 for genuinely strong answers and 10 for answers with no meaningful improvement. Do not inflate scores. Do not give every answer the same score; differentiate based on real quality.

SUB-RUBRICS:
- Behavioral: STAR completeness (Situation, Task, Action, Result), specificity of the example, ownership/agency demonstrated, lessons learned, authenticity (real-sounding vs hypothetical)
- Technical: correctness, depth of explanation, specific tools/patterns/standards named, awareness of trade-offs and edge cases, real-world calibration (not just textbook recitation)
- Systems / design: structure of the response, identification of key concerns, articulated trade-offs, concrete patterns/technologies, scaling and failure modes
- Culture / motivation: authenticity, self-awareness, value alignment, specific examples vs platitudes

STRENGTHS (3-6 bullets): Each must be grounded in something the candidate actually said. Paraphrase or reference a specific phrase from the answer. No generic praise like "well-structured" without saying what specifically worked.

WEAKNESSES (1-5 bullets; fewer is fine, do NOT pad): Real gaps a senior interviewer would notice. Each must be actionable — what specifically the candidate could add, clarify, or restructure to score higher. Distinguish "missing" (didn't mention X) from "wrong" (said X incorrectly). If the answer is excellent, give fewer weaknesses — that's correct calibration.

REWRITE: Produce a stronger version of the candidate's answer that would score 9-10. Keep the candidate's authentic voice and any specific examples they actually provided (do not fabricate new examples or experience claims). Roughly the same length as the original. Demonstrate what excellent looks like for this question type.

Reply with ONLY JSON: {"score": number, "strengths": string[], "weaknesses": string[], "rewrite": string}. No prose, no code fences.`;

  const userPrompt = `Question: ${question}\n\nCandidate's answer: ${answer.trim() || "(no answer given)"}`;

  let message;
  try {
    message = await anthropic.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 2048,
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

  try {
    const result = JSON.parse("{" + text) as {
      score: number;
      strengths: string[];
      weaknesses: string[];
      rewrite: string;
    };
    return NextResponse.json(result);
  } catch (e) {
    return NextResponse.json(
      {
        error: `Failed to parse model output: ${e instanceof Error ? e.message : String(e)}`,
        raw: text.slice(0, 400),
      },
      { status: 502 },
    );
  }
}
