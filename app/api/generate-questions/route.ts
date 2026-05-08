import { NextResponse } from "next/server";
import { z } from "zod";
import { anthropic, CLAUDE_MODEL } from "@/lib/anthropic";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const RequestSchema = z.object({
  role: z.string().min(1),
  industry: z.string().min(1),
  experienceLevel: z.enum(["entry", "mid", "senior"]),
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
  const { role, industry, experienceLevel } = parsed.data;

  const system = `You are a senior hiring manager at a top company in the candidate's target industry. You have run hundreds of interviews and know what separates great candidates from average ones.

Generate exactly 5 interview questions for a candidate matching the provided role, industry, and experience level. You MUST follow this category mix in this exact order — do not skip, swap, or duplicate categories:

POSITION 1 — Behavioral. Must begin with "Tell me about a time...", "Describe a situation when...", or similar STAR-prompt phrasing. Asks for a specific past experience.
POSITION 2 — Technical/role-specific. Probes depth in one area of the candidate's craft. Concrete, hands-on.
POSITION 3 — Technical/role-specific. A DIFFERENT technical area than position 2. Do not repeat the topic.
POSITION 4 — Systems/design or scenario. Requires structured thinking and explicit trade-off reasoning. Open-ended.
POSITION 5 — Culture-fit or motivation. Asks about values, working style, what the candidate looks for in a role/team, or why this industry. NOT a technical question. NOT a behavioral STAR question.

Calibrate difficulty to the experience level:
- "entry": fundamentals, learning ability, foundational concepts; do not expect deep architectural decisions or production war stories
- "mid": assume independent feature ownership; probe real production trade-offs and decision-making
- "senior": probe judgment, mentorship, ambiguity, multi-team coordination, and technical leadership

Each question must be specific to the industry — avoid generic questions that could apply to any company. Each should be answerable in 2-5 minutes of speaking. Avoid yes/no questions or trivia.

Reply with ONLY a JSON object: {"questions": string[]} containing exactly 5 questions in the order above. No prose, no code fences, no commentary.`;

  const userPrompt = `Role: ${role}\nIndustry: ${industry}\nExperience level: ${experienceLevel}`;

  let message;
  try {
    message = await anthropic.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 1024,
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
    const parsedJson = JSON.parse("{" + text) as { questions: string[] };
    if (
      !Array.isArray(parsedJson.questions) ||
      parsedJson.questions.length === 0
    ) {
      throw new Error("Model returned no questions.");
    }
    return NextResponse.json({ questions: parsedJson.questions });
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
