import { NextResponse } from "next/server";
import { z } from "zod";
import { anthropic, CLAUDE_MODEL } from "@/lib/anthropic";

export const runtime = "nodejs";

const RequestSchema = z.object({
  role: z.string().min(1),
  industry: z.string().min(1),
  experienceLevel: z.enum(["entry", "mid", "senior"]),
  answers: z
    .array(
      z.object({
        question: z.string().min(1),
        answer: z.string().min(1),
      })
    )
    .min(1),
});

export async function POST(req: Request) {
  const parsed = RequestSchema.safeParse(await req.json());
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }
  const { role, industry, experienceLevel, answers } = parsed.data;

  const system =
    "You are an expert interview coach. Score each answer 0-10, list strengths and weaknesses, and provide a rewritten stronger version. Respond ONLY with JSON of the form {\"items\":[{\"question\":string,\"score\":number,\"strengths\":string[],\"weaknesses\":string[],\"rewrite\":string}]}.";

  const user = `Candidate: ${experienceLevel}-level ${role} in ${industry}.\n\nEvaluate each Q/A pair below.\n\n${answers
    .map(
      (a, i) =>
        `Q${i + 1}: ${a.question}\nA${i + 1}: ${a.answer}`
    )
    .join("\n\n")}`;

  const message = await anthropic.messages.create({
    model: CLAUDE_MODEL,
    max_tokens: 4096,
    system,
    messages: [{ role: "user", content: user }],
  });

  const text = message.content
    .filter((b): b is { type: "text"; text: string } => b.type === "text")
    .map((b) => b.text)
    .join("");

  return NextResponse.json(JSON.parse(text));
}
