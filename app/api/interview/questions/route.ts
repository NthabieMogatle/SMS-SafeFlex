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

  const system =
    'You are an expert interview coach. Generate concise, role-specific interview questions. Reply with ONLY a JSON object of the form {"questions": string[]} containing exactly 5 questions. No prose, no code fences.';

  const userPrompt = `Generate 5 mock interview questions for a ${experienceLevel}-level ${role} candidate in the ${industry} industry. Mix behavioral and role-specific questions.`;

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
    if (!Array.isArray(parsedJson.questions) || parsedJson.questions.length === 0) {
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
