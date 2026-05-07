/* =========================================================================
 * Career OS — Mock Interview MVP (Build 1)
 * Pure-vanilla single-page app. Works offline with a built-in question bank
 * and rubric scorer. If a Claude API key is set in Settings, it upgrades to
 * AI-generated questions, feedback, and rewrites.
 * ======================================================================= */

const STORAGE_KEY = "career-os-state-v1";
const SETTINGS_KEY = "career-os-settings-v1";

// --------- State ---------
let state = {
  user: { name: "", role: "", company: "", style: "mixed", count: 5 },
  questions: [],   // [{ id, type, text, hint, role }]
  answers: [],     // [{ qid, text, scoreObj }]
  current: 0,      // index into questions
  practiceQid: null,
};

let settings = {
  apiKey: "",
  model: "claude-opus-4-7",
};

// --------- Storage ---------
function loadSettings() {
  try {
    const s = JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}");
    settings = { ...settings, ...s };
  } catch {}
}
function persistSettings() {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
}
function persistState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}
function loadState() {
  try {
    const s = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (s && s.questions && s.questions.length) state = s;
  } catch {}
}

// --------- Navigation ---------
function showPage(id) {
  document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
  document.querySelectorAll("nav a").forEach(a => a.classList.remove("active"));
  const page = document.getElementById(id);
  if (page) page.classList.add("active");
  const nav = document.getElementById("nav-" + id);
  if (nav) nav.classList.add("active");
  const titles = {
    setup: "Mock Interview Coach",
    interview: "Live Interview",
    feedback: "Per-Question Feedback",
    report: "Interview Report",
    practice: "Practice & Rewrite",
    settings: "Settings",
  };
  const sub = document.getElementById("subTitle");
  if (sub) sub.textContent = titles[id] || titles.setup;
  window.scrollTo({ top: 0, behavior: "smooth" });
}

// =========================================================================
// QUESTION BANK
// =========================================================================
const ROLE_BANK = {
  generic: [
    { type: "Behavioral", text: "Tell me about yourself.",
      hint: "60–90 seconds. Past → Present → Future. Tie it to the role." },
    { type: "Behavioral", text: "Describe a time you faced a major setback at work and how you handled it.",
      hint: "Use STAR: Situation, Task, Action, Result. Quantify the result." },
    { type: "Behavioral", text: "Tell me about a time you disagreed with a manager or teammate. How did you resolve it?",
      hint: "Show empathy, data-driven thinking, and a clear outcome." },
    { type: "Behavioral", text: "What's your greatest professional achievement, and why?",
      hint: "Pick something measurable. Explain your specific role and what you learned." },
    { type: "Motivational", text: "Why this role, and why now?",
      hint: "Connect your background, the company's mission, and your next 2–3 years." },
    { type: "Motivational", text: "Why do you want to work at this company specifically?",
      hint: "Mention 2 specific things about the company. Avoid generic praise." },
    { type: "Behavioral", text: "Tell me about a time you had to make a decision with incomplete information.",
      hint: "Show your decision framework, the trade-offs you weighed, and the result." },
    { type: "Behavioral", text: "Describe a time you led a project under tight deadlines.",
      hint: "Show prioritization, delegation, and a measurable outcome." },
  ],
  "marketing manager": [
    { type: "Role-specific", text: "Walk me through a campaign you ran end-to-end. What was the goal, your strategy, and the result?",
      hint: "Cover audience, channel mix, budget, KPI, and the lift you delivered." },
    { type: "Role-specific", text: "How would you launch a new product to a market where we have no brand recognition?",
      hint: "Talk segmentation, positioning, channels, budget split, and how you'd measure success." },
    { type: "Role-specific", text: "A campaign you own is missing its CAC target by 40%. What do you do in the first week?",
      hint: "Diagnose funnel stage, isolate variables, A/B test, kill what's not working." },
    { type: "Role-specific", text: "Pick one growth channel you're best at. Why is it your edge?",
      hint: "Be specific: SEO, paid social, lifecycle, partnerships, content, etc. Show expertise." },
  ],
  "product manager": [
    { type: "Role-specific", text: "How would you improve our flagship product? Pick any feature.",
      hint: "Identify a user, a problem, a hypothesis, a metric to move, and a measurable test." },
    { type: "Role-specific", text: "Tell me about a product trade-off you made between speed and quality.",
      hint: "Show the framework, the call you made, and what you'd do differently." },
    { type: "Role-specific", text: "How do you prioritize a roadmap when engineering, sales, and the CEO all want different things?",
      hint: "RICE, opportunity sizing, north-star alignment. Show calm, structured thinking." },
    { type: "Role-specific", text: "Estimate the daily active users of an app you use. Walk me through your reasoning.",
      hint: "Top-down vs bottom-up, sanity check, state your assumptions out loud." },
  ],
  "software engineer": [
    { type: "Role-specific", text: "Describe a technically difficult problem you solved recently.",
      hint: "Why was it hard? What did you try? What did you learn? Be concrete." },
    { type: "Role-specific", text: "How do you make trade-offs between code quality and shipping speed?",
      hint: "Tests, risk surface, blast radius, reversibility. Give an example." },
    { type: "Role-specific", text: "Tell me about a production incident you led. What happened and what changed after?",
      hint: "Detection → mitigation → root cause → postmortem actions." },
    { type: "Role-specific", text: "How do you decide when to refactor vs. rewrite vs. leave it alone?",
      hint: "Show a mental model, not just instinct. Use a real example." },
  ],
  "data analyst": [
    { type: "Role-specific", text: "Tell me about an analysis that changed a business decision.",
      hint: "Question → data → method → insight → decision → measurable impact." },
    { type: "Role-specific", text: "A stakeholder asks for a metric that's misleading. What do you do?",
      hint: "Show how you'd push back diplomatically and propose a better metric." },
    { type: "Role-specific", text: "Walk me through how you'd build a dashboard for our exec team from scratch.",
      hint: "Audience, top 5 metrics, refresh cadence, drill-downs, actionability." },
  ],
  "sales": [
    { type: "Role-specific", text: "Walk me through your typical sales process from first touch to close.",
      hint: "Stages, qualification framework (BANT/MEDDIC), avg cycle time, win rate." },
    { type: "Role-specific", text: "Tell me about the biggest deal you ever closed.",
      hint: "Deal size, complexity, key turning point, what you'd repeat." },
    { type: "Role-specific", text: "How do you handle a champion going dark mid-deal?",
      hint: "Multi-thread, value re-anchor, executive sponsor, urgency event." },
  ],
  "designer": [
    { type: "Role-specific", text: "Walk me through your design process on a recent project.",
      hint: "Discover → define → ideate → prototype → test → ship. Show artifacts." },
    { type: "Role-specific", text: "How do you handle disagreement with a PM on a design decision?",
      hint: "Data, user research, hypothesis testing. Show humility and rigor." },
    { type: "Role-specific", text: "Critique a design you didn't make — what works, what doesn't, what would you change?",
      hint: "Use heuristics: hierarchy, accessibility, IA, microcopy, motion." },
  ],
};

function pickRoleBank(role) {
  const r = (role || "").toLowerCase();
  // simple keyword match
  if (/\bmarketing\b/.test(r)) return ROLE_BANK["marketing manager"];
  if (/\bproduct\b/.test(r)) return ROLE_BANK["product manager"];
  if (/(software|engineer|developer|swe)\b/.test(r)) return ROLE_BANK["software engineer"];
  if (/(data|analyst|analytics|bi)\b/.test(r)) return ROLE_BANK["data analyst"];
  if (/(sales|account|ae|sdr|bdr)\b/.test(r)) return ROLE_BANK["sales"];
  if (/(design|ux|ui)\b/.test(r)) return ROLE_BANK["designer"];
  return null;
}

function buildLocalQuestions(role, style, count) {
  const generic = [...ROLE_BANK.generic];
  const roleBank = pickRoleBank(role) ? [...pickRoleBank(role)] : [];
  let pool = [];
  if (style === "behavioral") pool = generic.filter(q => q.type === "Behavioral" || q.type === "Motivational");
  else if (style === "role-specific") pool = roleBank.length ? roleBank : generic;
  else pool = [...roleBank, ...generic]; // mixed

  // shuffle then take count
  shuffle(pool);
  const picked = pool.slice(0, Math.max(1, parseInt(count, 10) || 5));
  return picked.map((q, i) => ({ id: "q" + (i + 1), ...q }));
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
}

// =========================================================================
// SCORING (rubric-based, fully offline)
// =========================================================================
const FILLERS = ["um", "uh", "like", "you know", "basically", "literally",
  "kind of", "sort of", "i guess", "i mean", "right?", "honestly", "actually",
  "so yeah", "stuff", "things"];
const STRONG_VERBS = ["led", "built", "shipped", "drove", "launched", "owned",
  "designed", "delivered", "scaled", "grew", "reduced", "increased", "saved",
  "created", "negotiated", "managed", "implemented", "optimized", "founded",
  "executed", "improved", "automated", "researched", "analyzed", "presented"];
const STAR_HINTS = {
  S: ["situation", "context", "at the time", "when i was", "we were", "the company", "my team"],
  T: ["task", "goal", "responsible", "i had to", "my job was", "challenge"],
  A: ["i ", "i'd", "i decided", "i built", "i led", "i created", "i shipped", "i ran", "we built", "we shipped"],
  R: ["result", "outcome", "%", "$", "impact", "increased", "reduced", "grew", "saved", "won", "we hit", "ended up"]
};

function scoreAnswer(question, text) {
  const cleaned = (text || "").trim();
  if (!cleaned) {
    return {
      total: 0, verdict: "No answer", summary: "You didn't provide an answer.",
      strengths: [], weaknesses: ["You skipped this question."],
      metrics: { length: 0, fillers: 0, structure: 0, specificity: 0, energy: 0 }
    };
  }
  const lc = cleaned.toLowerCase();
  const words = cleaned.split(/\s+/).filter(Boolean);
  const wc = words.length;

  // 1) length (0-100): sweet spot 150–350 words for a typical answer
  let lengthScore;
  if (wc < 40) lengthScore = Math.round((wc / 40) * 50);
  else if (wc < 120) lengthScore = 50 + Math.round(((wc - 40) / 80) * 30);
  else if (wc <= 350) lengthScore = 95;
  else if (wc <= 500) lengthScore = 80;
  else lengthScore = Math.max(50, 80 - Math.round((wc - 500) / 20));

  // 2) fillers (0-100): more fillers = lower
  let fillerCount = 0;
  FILLERS.forEach(f => {
    const re = new RegExp("\\b" + f.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b", "gi");
    const m = cleaned.match(re);
    if (m) fillerCount += m.length;
  });
  const fillersPer100 = wc ? (fillerCount / wc) * 100 : 0;
  const fillerScore = Math.max(0, Math.round(100 - fillersPer100 * 25));

  // 3) STAR structure (0-100)
  const starHits = Object.keys(STAR_HINTS).map(k => {
    const arr = STAR_HINTS[k];
    return arr.some(p => lc.includes(p)) ? 1 : 0;
  });
  const starScore = Math.round((starHits.reduce((a, b) => a + b, 0) / 4) * 100);

  // 4) specificity: numbers, %, $, named entities (capitalized words after first)
  const numberMatches = (cleaned.match(/\b\d[\d,\.]*\b/g) || []).length;
  const percentMatches = (cleaned.match(/%/g) || []).length;
  const dollarMatches = (cleaned.match(/\$/g) || []).length;
  const properNouns = (cleaned.match(/\b[A-Z][a-zA-Z]{2,}/g) || []).length - 1;
  const specificityRaw = numberMatches * 12 + percentMatches * 10 + dollarMatches * 10 + Math.max(0, properNouns) * 4;
  const specificityScore = Math.min(100, specificityRaw);

  // 5) energy: strong action verbs density
  let strongVerbHits = 0;
  STRONG_VERBS.forEach(v => {
    const re = new RegExp("\\b" + v + "\\b", "gi");
    const m = cleaned.match(re);
    if (m) strongVerbHits += m.length;
  });
  const energyScore = Math.min(100, Math.round((strongVerbHits / Math.max(1, wc / 50)) * 30));

  // weighted total
  const total = Math.round(
    lengthScore * 0.15 +
    fillerScore * 0.20 +
    starScore * 0.25 +
    specificityScore * 0.25 +
    energyScore * 0.15
  );

  // strengths / weaknesses
  const strengths = [];
  const weaknesses = [];

  if (lengthScore >= 80) strengths.push("Length is about right for this kind of answer.");
  else if (wc < 40) weaknesses.push(`Far too short (${wc} words). Aim for 150–300 words.`);
  else if (wc < 120) weaknesses.push(`A bit short (${wc} words). Add a concrete example with numbers.`);
  else if (wc > 500) weaknesses.push(`Too long (${wc} words). Cut by ~30% — interviewers tune out after ~2 minutes.`);

  if (fillerScore >= 85) strengths.push("Almost no filler words — your delivery sounds confident.");
  else if (fillerCount > 0) weaknesses.push(`You used filler words ${fillerCount} time${fillerCount === 1 ? "" : "s"} (e.g. "um", "like", "basically"). Pause instead.`);

  if (starScore >= 75) strengths.push("Clear STAR structure — situation, action, and result are visible.");
  else if (starHits[3] === 0) weaknesses.push("No clear result. Quantify the outcome (%, $, time saved, retention lift).");
  else if (starHits[2] === 0) weaknesses.push("Missing your specific actions. Use \"I…\" not \"we…\" so the interviewer knows what YOU did.");
  else if (starHits[0] + starHits[1] === 0) weaknesses.push("Set the scene faster — what was the situation and the goal?");

  if (specificityScore >= 70) strengths.push("Strong specificity — numbers, names, and concrete details.");
  else if (numberMatches === 0 && percentMatches === 0 && dollarMatches === 0) weaknesses.push("Zero numbers in your answer. Add at least one metric (%, $, time, count).");

  if (energyScore >= 60) strengths.push("Strong action verbs — sounds like an owner, not a passenger.");
  else if (strongVerbHits < 2) weaknesses.push("Use stronger verbs: led, shipped, built, drove, owned, reduced, increased.");

  // verdict
  let verdict;
  if (total >= 85) verdict = "Strong answer";
  else if (total >= 70) verdict = "Solid — small fixes will make it great";
  else if (total >= 55) verdict = "Workable, but needs sharpening";
  else if (total >= 35) verdict = "Weak — let's rebuild this one";
  else verdict = "Needs a full rewrite";

  const summary = `Length ${lengthScore} • Fillers ${fillerScore} • Structure ${starScore} • Specificity ${specificityScore} • Energy ${energyScore}`;

  return {
    total, verdict, summary, strengths, weaknesses,
    metrics: {
      length: lengthScore, fillers: fillerScore, structure: starScore,
      specificity: specificityScore, energy: energyScore
    },
    counts: { words: wc, fillers: fillerCount, numbers: numberMatches }
  };
}

// =========================================================================
// REWRITE (offline template-based)
// =========================================================================
function rewriteAnswer(question, original) {
  const role = state.user.role || "this role";
  const company = state.user.company ? ` at ${state.user.company}` : "";
  const orig = (original || "").trim();
  const wc = orig.split(/\s+/).filter(Boolean).length;

  const note = "This is a structural template using the STAR method (Situation, Task, Action, Result). Replace the bracketed parts with your real specifics — numbers, names, and outcomes — to make it yours.";

  const example = `Sure — let me give you a concrete example.

[Situation] About [time period] ago${company ? ", while working on " + state.user.company : ""}, my team was facing [specific challenge with one number, e.g. a 30% drop in conversion]. The stakes were [why it mattered: revenue, deadline, customer impact].

[Task] As the ${role}, I owned [specific deliverable]. The bar was [concrete success metric — e.g. recover 20% within Q3].

[Action] Here's what I did. First, I [diagnostic step — what data you pulled or who you talked to]. Then, I [decision you made and why, in one sentence]. I led [the team / cross-functional partners], and we shipped [specific things, 2–3 of them]. The hardest call was [trade-off you made], and I chose [your call] because [reason].

[Result] We [hit / exceeded / missed by a hair] the goal. Concretely: [metric] went from [X] to [Y], which was a [%] lift. Beyond the number, [what changed for users / the team / the company]. The biggest lesson I took away was [one sharp lesson you'd reuse].`;

  return { text: example, note };
}

// =========================================================================
// CLAUDE API (optional)
// =========================================================================
async function claudeCall(systemPrompt, userPrompt) {
  if (!settings.apiKey) throw new Error("No API key");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": settings.apiKey,
      "anthropic-version": "2023-06-01",
      "anthropic-dangerous-direct-browser-access": "true"
    },
    body: JSON.stringify({
      model: settings.model || "claude-opus-4-7",
      max_tokens: 1500,
      system: systemPrompt,
      messages: [{ role: "user", content: userPrompt }]
    })
  });
  if (!res.ok) {
    const errText = await res.text().catch(() => "");
    throw new Error(`Claude API ${res.status}: ${errText.slice(0, 300)}`);
  }
  const data = await res.json();
  const block = (data.content || []).find(b => b.type === "text");
  return block ? block.text : "";
}

async function aiBuildQuestions(role, company, style, count) {
  const sys = "You are an expert interview coach. Return ONLY a JSON array, no prose, no code fences. Each item: {\"type\":\"Behavioral|Role-specific|Motivational\",\"text\":\"...\",\"hint\":\"...\"}.";
  const user = `Generate ${count} mock interview questions for a ${role}${company ? " at " + company : ""}. Style: ${style}. Mix at least one motivational ("why this role/company") question. Hints should be one sentence of coaching guidance.`;
  const raw = await claudeCall(sys, user);
  const json = extractJSON(raw);
  if (!Array.isArray(json)) throw new Error("Bad question JSON");
  return json.map((q, i) => ({ id: "q" + (i + 1), type: q.type || "Behavioral", text: q.text, hint: q.hint || "" }));
}

async function aiScoreAnswer(question, answer) {
  const sys = `You are a tough but fair interview coach. Return ONLY JSON: {"total":0-100,"verdict":"...","summary":"...","strengths":["..."],"weaknesses":["..."],"metrics":{"length":0-100,"fillers":0-100,"structure":0-100,"specificity":0-100,"energy":0-100}}`;
  const user = `Question: ${question}\n\nCandidate's answer:\n"""\n${answer}\n"""\n\nScore the answer. Be specific. Strengths and weaknesses must reference actual phrases from the answer.`;
  const raw = await claudeCall(sys, user);
  const json = extractJSON(raw);
  if (!json || typeof json.total !== "number") throw new Error("Bad score JSON");
  json.counts = scoreAnswer(question, answer).counts;
  return json;
}

async function aiRewriteAnswer(question, answer) {
  const role = state.user.role || "the role";
  const company = state.user.company || "";
  const sys = "You are an elite interview coach. Rewrite the candidate's answer using STAR. Keep their authentic voice. Be specific, concise, and quantified. Return ONLY JSON: {\"text\":\"...\",\"note\":\"one-sentence coaching note\"}.";
  const user = `Role: ${role}${company ? "\nCompany: " + company : ""}\nQuestion: ${question}\n\nOriginal answer:\n"""\n${answer || "(no answer given)"}\n"""\n\nRewrite as the gold-standard answer. ~200 words.`;
  const raw = await claudeCall(sys, user);
  const json = extractJSON(raw);
  if (!json || !json.text) throw new Error("Bad rewrite JSON");
  return json;
}

function extractJSON(s) {
  if (!s) return null;
  // strip code fences
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fence ? fence[1] : s;
  try { return JSON.parse(candidate); } catch {}
  // try to find first {...} or [...]
  const m = candidate.match(/(\[[\s\S]*\]|\{[\s\S]*\})/);
  if (m) { try { return JSON.parse(m[1]); } catch {} }
  return null;
}

// =========================================================================
// FLOW
// =========================================================================
async function startInterview() {
  const name = (document.getElementById("userName").value || "").trim();
  const role = (document.getElementById("targetRole").value || "").trim();
  const company = (document.getElementById("targetCompany").value || "").trim();
  const style = document.getElementById("interviewStyle").value;
  const count = parseInt(document.getElementById("questionCount").value, 10) || 5;

  if (!role) {
    setHint("setupHint", "Please enter your target role to start.", "warn");
    return;
  }

  state = {
    user: { name, role, company, style, count },
    questions: [], answers: [], current: 0, practiceQid: null,
  };

  const btn = document.querySelector("#setup .primary");
  btn.disabled = true; btn.textContent = "Preparing questions…";

  try {
    if (settings.apiKey) {
      try {
        state.questions = await aiBuildQuestions(role, company, style, count);
      } catch (e) {
        console.warn("AI question gen failed, falling back:", e);
        state.questions = buildLocalQuestions(role, style, count);
      }
    } else {
      state.questions = buildLocalQuestions(role, style, count);
    }
  } finally {
    btn.disabled = false; btn.textContent = "Start Mock Interview →";
  }

  state.answers = state.questions.map(q => ({ qid: q.id, text: "", scoreObj: null }));
  persistState();
  showPage("interview");
  renderQuestion();
}

function renderQuestion() {
  const q = state.questions[state.current];
  if (!q) return;
  document.getElementById("qMeta").textContent = q.type || "Question";
  document.getElementById("qText").textContent = q.text;
  document.getElementById("qHint").textContent = q.hint || "";
  document.getElementById("answerBox").value = state.answers[state.current]?.text || "";
  updateAnswerMeta();
  const pct = ((state.current) / state.questions.length) * 100;
  document.getElementById("progressFill").style.width = pct + "%";
  document.getElementById("progressText").textContent =
    `Question ${state.current + 1} of ${state.questions.length}`;
}

function updateAnswerMeta() {
  const t = document.getElementById("answerBox").value || "";
  const wc = t.trim() ? t.trim().split(/\s+/).length : 0;
  const seconds = Math.round(wc / 2.5); // ~150 wpm spoken
  document.getElementById("wordCount").textContent = `${wc} words`;
  document.getElementById("readTime").textContent = `~${seconds}s spoken`;
}

async function submitAnswer() {
  const q = state.questions[state.current];
  const text = (document.getElementById("answerBox").value || "").trim();
  state.answers[state.current] = { qid: q.id, text, scoreObj: null };
  persistState();

  // local score immediately, then optionally upgrade with AI
  let scoreObj = scoreAnswer(q.text, text);

  if (settings.apiKey && text) {
    const btn = document.querySelector("#interview .primary");
    btn.disabled = true; btn.textContent = "Scoring…";
    try {
      const ai = await aiScoreAnswer(q.text, text);
      // merge: prefer AI strengths/weaknesses, keep our metrics fallback
      scoreObj = {
        total: clamp(ai.total ?? scoreObj.total, 0, 100),
        verdict: ai.verdict || scoreObj.verdict,
        summary: ai.summary || scoreObj.summary,
        strengths: ai.strengths || scoreObj.strengths,
        weaknesses: ai.weaknesses || scoreObj.weaknesses,
        metrics: { ...scoreObj.metrics, ...(ai.metrics || {}) },
        counts: scoreObj.counts,
      };
    } catch (e) {
      console.warn("AI scoring failed, using local rubric:", e);
    } finally {
      btn.disabled = false; btn.textContent = "Submit Answer →";
    }
  }

  state.answers[state.current].scoreObj = scoreObj;
  persistState();
  renderFeedback();
  showPage("feedback");
}

function clamp(n, lo, hi) { return Math.max(lo, Math.min(hi, n)); }

function skipQuestion() {
  const q = state.questions[state.current];
  state.answers[state.current] = { qid: q.id, text: "", scoreObj: scoreAnswer(q.text, "") };
  persistState();
  nextQuestion();
}

function renderFeedback() {
  const q = state.questions[state.current];
  const a = state.answers[state.current];
  const s = a.scoreObj || scoreAnswer(q.text, a.text);

  document.getElementById("fbMeta").textContent = `Question ${state.current + 1} of ${state.questions.length}`;
  document.getElementById("fbQuestion").textContent = q.text;
  document.getElementById("fbScore").textContent = s.total;
  document.getElementById("fbVerdict").textContent = s.verdict;
  document.getElementById("fbSummary").textContent = s.summary;

  const ring = document.getElementById("fbRing");
  ring.style.setProperty("--ring", s.total);
  ring.style.setProperty("--ring-color", scoreColor(s.total));

  const strengths = document.getElementById("fbStrengths");
  strengths.innerHTML = (s.strengths || []).map(t => `<li><b>✓</b><span>${esc(t)}</span></li>`).join("")
    || `<li><b>—</b><span>No clear strengths yet — that's normal early on.</span></li>`;

  const weaknesses = document.getElementById("fbWeaknesses");
  weaknesses.innerHTML = (s.weaknesses || []).map(t => `<li><b>!</b><span>${esc(t)}</span></li>`).join("")
    || `<li><b>✓</b><span>No major issues — solid answer.</span></li>`;

  document.getElementById("fbYourAnswer").textContent = a.text || "(no answer)";
}

function scoreColor(n) {
  if (n >= 80) return "var(--good)";
  if (n >= 60) return "var(--accent)";
  if (n >= 40) return "var(--warn)";
  return "var(--bad)";
}

function nextQuestion() {
  if (state.current < state.questions.length - 1) {
    state.current++;
    persistState();
    showPage("interview");
    renderQuestion();
  } else {
    renderReport();
    showPage("report");
  }
}

function restart() {
  if (!confirm("Start a new interview? Your current answers will be cleared.")) return;
  localStorage.removeItem(STORAGE_KEY);
  state = {
    user: { name: "", role: "", company: "", style: "mixed", count: 5 },
    questions: [], answers: [], current: 0, practiceQid: null,
  };
  showPage("setup");
}

// =========================================================================
// REPORT
// =========================================================================
function renderReport() {
  const scored = state.answers.map((a, i) => {
    const q = state.questions[i];
    const s = a.scoreObj || scoreAnswer(q.text, a.text);
    return { q, a, s };
  });

  const total = Math.round(scored.reduce((sum, x) => sum + x.s.total, 0) / Math.max(1, scored.length));
  document.getElementById("reportScore").textContent = total;
  const ring = document.getElementById("reportRing");
  ring.style.setProperty("--ring", total);
  ring.style.setProperty("--ring-color", scoreColor(total));

  const name = state.user.name ? state.user.name + ", " : "";
  document.getElementById("reportTitle").textContent =
    `${name}here's your interview report`;
  document.getElementById("reportSummary").textContent =
    `${state.user.role}${state.user.company ? " at " + state.user.company : ""} · ${scored.length} questions · ${verdictForTotal(total)}`;

  // breakdown — average each metric
  const keys = ["length", "fillers", "structure", "specificity", "energy"];
  const labels = {
    length: "Answer length",
    fillers: "Filler words",
    structure: "STAR structure",
    specificity: "Specificity (numbers, names)",
    energy: "Action verbs / ownership",
  };
  const avg = {};
  keys.forEach(k => {
    avg[k] = Math.round(scored.reduce((s, x) => s + (x.s.metrics?.[k] ?? 0), 0) / Math.max(1, scored.length));
  });
  const breakdown = document.getElementById("reportBreakdown");
  breakdown.innerHTML = keys.map(k => `
    <div class="metric">
      <span>${labels[k]}</span>
      <div class="bar"><span style="width:${avg[k]}%"></span></div>
      <b>${avg[k]}</b>
    </div>
  `).join("");

  // per-question
  const list = document.getElementById("reportQuestions");
  list.innerHTML = scored.map((x, i) => {
    const cls = x.s.total >= 75 ? "good" : x.s.total >= 50 ? "mid" : "low";
    return `
      <li>
        <div class="qhead"><b>Q${i + 1}</b><span class="qscore ${cls}">${x.s.total}/100</span></div>
        <div>${esc(x.q.text)}</div>
        <p class="muted" style="margin:8px 0 0">${esc(x.s.verdict)} — ${esc((x.s.weaknesses && x.s.weaknesses[0]) || (x.s.strengths && x.s.strengths[0]) || "")}</p>
      </li>
    `;
  }).join("");

  // next steps
  const lowest = [...keys].sort((a, b) => avg[a] - avg[b]).slice(0, 3);
  const tips = {
    length: "Practice trimming long answers — aim for 90–180 seconds spoken.",
    fillers: "Replace filler words with a 1-second pause. Record yourself and count.",
    structure: "Use STAR for every behavioral answer: Situation, Task, Action, Result.",
    specificity: "Add at least one number to every answer (%, $, time, count, team size).",
    energy: "Lead with strong verbs: led, shipped, built, drove, owned, reduced, grew.",
  };
  document.getElementById("reportNextSteps").innerHTML = lowest
    .map(k => `<li><b>→</b><span>${tips[k]}</span></li>`).join("");
}

function verdictForTotal(n) {
  if (n >= 85) return "You're interview-ready.";
  if (n >= 70) return "Close — polish 2–3 answers and you're there.";
  if (n >= 55) return "Solid base, but needs sharpening before the real thing.";
  if (n >= 35) return "We've got real work to do — let's start with your weakest answers.";
  return "Let's rebuild from the ground up. One answer at a time.";
}

// =========================================================================
// PRACTICE / REWRITE
// =========================================================================
async function practiceCurrent() {
  const q = state.questions[state.current];
  state.practiceQid = q.id;
  await openPractice(q.id);
}

async function practiceWeakest() {
  let weakest = null, low = 101;
  state.answers.forEach((a, i) => {
    const score = a.scoreObj?.total ?? 0;
    if (score < low) { low = score; weakest = i; }
  });
  if (weakest == null) return;
  state.practiceQid = state.questions[weakest].id;
  await openPractice(state.practiceQid);
}

async function openPractice(qid) {
  const idx = state.questions.findIndex(q => q.id === qid);
  if (idx < 0) return;
  const q = state.questions[idx];
  const a = state.answers[idx];

  document.getElementById("prQuestion").textContent = q.text;
  document.getElementById("prYourAnswer").textContent = a.text || "(you skipped this question)";
  document.getElementById("prImproved").textContent = "Generating an improved version…";
  document.getElementById("prImprovedNote").textContent = "";
  document.getElementById("prRetry").value = "";
  document.getElementById("prRetryFeedback").textContent = "";
  showPage("practice");

  let rewrite;
  if (settings.apiKey) {
    try { rewrite = await aiRewriteAnswer(q.text, a.text); }
    catch (e) {
      console.warn("AI rewrite failed, using template:", e);
      rewrite = rewriteAnswer(q.text, a.text);
    }
  } else {
    rewrite = rewriteAnswer(q.text, a.text);
  }
  document.getElementById("prImproved").textContent = rewrite.text;
  document.getElementById("prImprovedNote").textContent = rewrite.note || "";
}

async function scoreRetry() {
  const idx = state.questions.findIndex(q => q.id === state.practiceQid);
  if (idx < 0) return;
  const q = state.questions[idx];
  const text = document.getElementById("prRetry").value || "";
  if (!text.trim()) {
    setHint("prRetryFeedback", "Write your own version above first.", "warn");
    return;
  }

  let s = scoreAnswer(q.text, text);
  if (settings.apiKey) {
    const btn = document.querySelector("#practice .primary");
    btn.disabled = true; btn.textContent = "Scoring…";
    try { s = await aiScoreAnswer(q.text, text); }
    catch (e) { console.warn(e); }
    finally { btn.disabled = false; btn.textContent = "Score this version →"; }
  }

  // also update the stored answer & rescore the report
  state.answers[idx] = { qid: q.id, text, scoreObj: s };
  persistState();

  const prev = state.answers[idx]?.scoreObj?.total ?? 0;
  const delta = s.total - prev;
  const arrow = delta > 0 ? "▲" : delta < 0 ? "▼" : "→";
  setHint("prRetryFeedback",
    `New score: ${s.total}/100 ${arrow} (${s.verdict}). Updated your interview report.`,
    s.total >= 70 ? "good" : "warn");
}

function backToReport() {
  renderReport();
  showPage("report");
}

// =========================================================================
// SETTINGS
// =========================================================================
function saveSettings() {
  settings.apiKey = (document.getElementById("apiKey").value || "").trim();
  settings.model = document.getElementById("apiModel").value;
  persistSettings();
  setHint("settingsHint",
    settings.apiKey
      ? "Saved. AI-powered questions and feedback are now enabled."
      : "Saved. Running in offline mode with the built-in coach.",
    "good");
}

function setHint(id, msg, tone) {
  const el = document.getElementById(id);
  if (!el) return;
  el.textContent = msg;
  el.style.color =
    tone === "good" ? "var(--good)" :
    tone === "warn" ? "var(--warn)" :
    "var(--muted)";
}

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
  }[c]));
}

// =========================================================================
// INIT
// =========================================================================
document.addEventListener("DOMContentLoaded", () => {
  loadSettings();
  loadState();

  // hydrate settings UI
  document.getElementById("apiKey").value = settings.apiKey || "";
  document.getElementById("apiModel").value = settings.model || "claude-opus-4-7";

  // hydrate setup UI from prior session
  if (state.user.role) document.getElementById("targetRole").value = state.user.role;
  if (state.user.name) document.getElementById("userName").value = state.user.name;
  if (state.user.company) document.getElementById("targetCompany").value = state.user.company;

  // live word count
  const box = document.getElementById("answerBox");
  if (box) box.addEventListener("input", updateAnswerMeta);

  // resume in-progress interview
  if (state.questions.length && state.current < state.questions.length) {
    showPage("interview");
    renderQuestion();
  } else if (state.questions.length && state.current >= state.questions.length) {
    renderReport();
    showPage("report");
  } else {
    showPage("setup");
  }
});

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("./service-worker.js").catch(() => {});
  });
}
