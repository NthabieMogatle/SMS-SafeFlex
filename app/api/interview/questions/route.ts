import { NextResponse } from "next/server";
import { z } from "zod";
import { anthropic, CLAUDE_MODEL } from "@/lib/anthropic";

export const runtime = "nodejs";

const RequestSchema = z.object({
  role: z.string().min(1),
  industry: z.string().min(1),
  experienceLevel: z.enum(["entry", "mid", "senior"]),
});

export async function POST(req: Request) {
  const parsed = RequestSchema.safeParse(await req.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }
  const { role, industry, experienceLevel } = parsed.data;

  const system =
    "You are an expert interview coach. Generate concise, role-specific interview questions. Respond ONLY with a JSON object of the form {\"questions\": string[]} containing exactly 5 questions.";

  const user = `Generate 5 mock interview questions for a ${experienceLevel}-level ${role} candidate in the ${industry} industry. Mix behavioral and role-specific questions.`;

  const message = await anthropic.messages.create({
    model: CLAUDE_MODEL,
    max_tokens: 1024,
    system,
    messages: [{ role: "user", content: user }],
  });

  const text = message.content
    .filter((b): b is { type: "text"; text: string } => b.type === "text")
    .map((b) => b.text)
    .join("");

  const questions = JSON.parse(text).questions as string[];
  return NextResponse.json({ questions });
}
