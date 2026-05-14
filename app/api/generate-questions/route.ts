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

  // Fetch this user's previous Q1s across ALL role/industry/level configs.
  // The original fix scoped this lookup to the same (role, industry, level)
  // bucket, which meant the user's first interview in any new bucket saw an
  // empty anti-repetition context — the exact case where Q1 most strongly
  // converges on the same most-likely opener. Cross-config lookup gives
  // coverage from interview 2 onward regardless of config changes.
  let previousFirstQuestions: string[] = [];
  try {
    const { data: priorInterviews } = await supabase
      .from("interviews")
      .select("questions")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false })
      .limit(5);
    previousFirstQuestions = (priorInterviews ?? [])
      .map((row) => {
        const qs = (row as { questions: unknown }).questions;
        return Array.isArray(qs) && typeof qs[0] === "string" ? qs[0] : null;
      })
      .filter((q): q is string => !!q);
  } catch {
    // Best-effort: if the lookup fails (e.g. column missing in some envs),
    // fall back to generating without anti-repetition context.
  }

  const antiRepetitionBlock =
    previousFirstQuestions.length > 0
      ? `\n\nANTI-REPETITION FOR POSITION 1 — CRITICAL:
This candidate has previously been asked these Position 1 (behavioral) opening questions in prior interviews:
${previousFirstQuestions.map((q, i) => `${i + 1}. ${q}`).join("\n")}

Your Position 1 question MUST be substantially different from every question above. "Substantially different" means:
- A different scenario or competency being probed than any above
- Not just a rephrasing or a swapped closing clause of an above question
- The first ~15 words must not closely mirror any above question

Still must satisfy the Position 1 format (STAR-prompt phrasing, behavioral, specific past experience) and the scenario seed below.`
      : "";

  // Scenario seed: pick one behavioral competency at random per request and
  // require Position 1 to center on it. This is the cold-start defense —
  // when the anti-repetition history is empty (first interview by a new
  // user, or first interview in a new role/industry/level bucket), the
  // model otherwise converges on the same most-likely opener for identical
  // inputs. Forcing a randomly-chosen scenario breaks that attractor.
  const SCENARIO_SEEDS = [
    "a conflict with a teammate or stakeholder",
    "a failure or a project that didn't go as planned",
    "shifting requirements or a major scope change mid-project",
    "mentoring or developing a more junior colleague",
    "operating under significant ambiguity or incomplete information",
    "competing priorities or having to deprioritize important work",
    "pushback from a senior stakeholder or executive",
    "paying down technical debt or refactoring a critical system",
    "a cross-functional disagreement (e.g. eng vs design, eng vs PM)",
    "delivering difficult news to a customer, exec, or team",
  ];
  const scenarioSeed =
    SCENARIO_SEEDS[Math.floor(Math.random() * SCENARIO_SEEDS.length)];

  const system = `You are a senior hiring manager at a top company in the candidate's target industry. You have run hundreds of interviews and know what separates great candidates from average ones.

Generate exactly 5 interview questions for a candidate matching the provided role, industry, and experience level. You MUST follow this category mix in this exact order — do not skip, swap, or duplicate categories:

POSITION 1 — Behavioral. Must begin with "Tell me about a time...", "Describe a situation when...", or similar STAR-prompt phrasing. Asks for a specific past experience. For THIS interview, the Position 1 scenario MUST center on: ${scenarioSeed}. Do not substitute a different competency.
POSITION 2 — Technical/role-specific. Probes depth in one area of the candidate's craft. Concrete, hands-on.
POSITION 3 — Technical/role-specific. A DIFFERENT technical area than position 2. Do not repeat the topic.
POSITION 4 — Systems/design or scenario. Requires structured thinking and explicit trade-off reasoning. Open-ended.
POSITION 5 — Culture-fit or motivation. Asks about values, working style, what the candidate looks for in a role/team, or why this industry. NOT a technical question. NOT a behavioral STAR question.

Calibrate difficulty to the experience level:
- "entry": fundamentals, learning ability, foundational concepts; do not expect deep architectural decisions or production war stories
- "mid": assume independent feature ownership; probe real production trade-offs and decision-making
- "senior": probe judgment, mentorship, ambiguity, multi-team coordination, and technical leadership

Each question must be specific to the industry — avoid generic questions that could apply to any company. Each should be answerable in 2-5 minutes of speaking. Avoid yes/no questions or trivia.${antiRepetitionBlock}

Reply with ONLY a JSON object: {"questions": string[]} containing exactly 5 questions in the order above. No prose, no code fences, no commentary.`;

  const userPrompt = `Role: ${role}\nIndustry: ${industry}\nExperience level: ${experienceLevel}`;

  let message;
  try {
    message = await anthropic.messages.create({
      model: CLAUDE_MODEL,
      max_tokens: 1024,
      // Higher temperature combats Q1 convergence: with the default
      // sampling, the heavily-constrained Position 1 prompt keeps producing
      // the same most-likely opener across sessions for identical inputs.
      temperature: 0.85,
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
