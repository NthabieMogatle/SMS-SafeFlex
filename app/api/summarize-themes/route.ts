import { NextResponse } from "next/server";
import { z } from "zod";
import { anthropic, CLAUDE_MODEL } from "@/lib/anthropic";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const RequestSchema = z.object({
  weaknesses: z.array(z.array(z.string())).min(1),
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
  const { weaknesses } = parsed.data;

  const flat = weaknesses.flat().filter(Boolean);
  if (flat.length === 0) {
    return NextResponse.json({ themes: [] });
  }

  const system = `You are a supportive interview coach helping a candidate identify the highest-leverage things to work on after a mock interview.

You will be given the per-question weakness bullets from a single mock interview. Identify the 1-3 most common patterns across all the weaknesses and output them as concise, actionable coaching suggestions.

REQUIREMENTS:
- Return between 1 and 3 themes. Fewer is fine if the patterns aren't clear.
- Each theme must be ≤15 words.
- Each theme must be actionable — describe what to DO, not what was wrong.
- Each theme must capture a pattern across multiple questions, not a single isolated issue.
- Do not repeat the same theme in different words.

TONE: coaching and encouraging, never harsh. Action-oriented.

GOOD EXAMPLES (style, not content):
- "Add specific metrics to quantify impact in your stories"
- "Use the STAR structure more consistently for behavioral questions"
- "Reference industry-specific frameworks (e.g. PCI-DSS, GDPR) when relevant"

BAD EXAMPLES (avoid):
- "Communicate better" (too generic)
- "Your answers were short" (not actionable)
- "Failed to mention X" (a single-question weakness, not a pattern)

Reply with ONLY JSON: {"themes": string[]}. No prose, no code fences.`;

  const userPrompt = `Per-question weaknesses from this candidate's mock interview:\n\n${weaknesses
    .map((qWeaknesses, i) =>
      qWeaknesses.length === 0
        ? `Q${i + 1}: (no weaknesses identified)`
        : `Q${i + 1}:\n${qWeaknesses.map((w) => `  - ${w}`).join("\n")}`,
    )
    .join("\n\n")}`;

  let message;
  try {
    message = await anthropic.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 512,
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
    const parsedJson = JSON.parse("{" + text) as { themes: string[] };
    const themes = Array.isArray(parsedJson.themes)
      ? parsedJson.themes.slice(0, 3).filter((t) => typeof t === "string")
      : [];
    return NextResponse.json({ themes });
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
