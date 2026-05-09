# Elevra

> The interview, elevated.

Elevra is an AI mock interview coach that elevates your interview answers
— pulling rough responses up to interview-winning quality with AI scoring,
targeted feedback, and rewritten model answers.

## What it does

- Generates 5 mock interview questions calibrated to your target role,
  industry, and experience level
- Lets you answer by typing or by speaking (voice input via the Web
  Speech API)
- Scores each answer 0–10 with a senior-hiring-manager rubric
- Surfaces strengths, weaknesses, and a rewritten "what excellent looks
  like" version of every answer
- Distills the top 3 coaching themes across the whole interview
- Tracks your score over time, with a Practice Next card that remembers
  the patterns to focus on in your next session

## Stack

| Layer | Choice |
|---|---|
| Framework | Next.js 14 (App Router) |
| Hosting | Vercel |
| Auth + DB | Supabase (Postgres, RLS) |
| AI | Anthropic Claude (Sonnet 4.5) |
| Styling | Tailwind CSS |
| Voice | Web Speech API |

## Getting started

```bash
git clone <this repo>
cd elevra
npm install
cp .env.local.example .env.local
# fill in NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY,
# ANTHROPIC_API_KEY, NEXT_PUBLIC_SITE_URL, ADMIN_SECRET
npm run dev
```

Open http://localhost:3000.

## Routes

### Public
- `/` — marketing landing
- `/login`, `/signup` — auth (Supabase email + password)
- `/privacy`, `/terms` — legal
- `/opengraph-image` — auto-generated social preview (1200×630 PNG)

### Authenticated
- `/setup` — capture target role, industry, experience level
- `/interview` — 5-question mock interview, voice + text input,
  auto-saved drafts in localStorage
- `/feedback` — scored report with the 📊 Top 3 things to work on,
  plus per-question strengths / weaknesses / rewrites
- `/dashboard` — score-over-time chart, recent trend, practice-next
  card, full session history
- `/account` — current plan, monthly usage bar, redeem code form

### API
- `POST /api/generate-questions` — creates 5 questions
- `POST /api/score-answer` — scores a single answer
- `POST /api/summarize-themes` — extracts top 3 coaching themes
- `POST /api/redeem` — claims a redemption code, upgrades plan
- `POST /api/webhooks/appsumo` — partner webhook (HMAC-verified)

### Admin (gated by `ADMIN_SECRET` query param)
- `/admin/health?key=…` — env vars + Supabase reachability
- `/admin/api-test?key=…` — interactive endpoint tester

## Plans

- **Free** — 3 interviews per month, full feedback, themes, history
- **Lifetime** — unlimited interviews, one-time payment, distributed via
  partner platforms

Lifetime tiers are claimed by entering a code at `/account`. Codes are
seeded in the `redemption_codes` table; for partner integrations the
webhook at `/api/webhooks/appsumo` mints codes automatically on purchase
and revokes them on refund.

## Database

Schema migrations live in `supabase/schema.sql`. Tables:

- `profiles` — one row per user (target role, industry, experience
  level, plan_tier)
- `interviews` — one row per session (questions, answers, feedback,
  themes, score)
- `redemption_codes` — codes that grant a plan_tier when claimed
- `appsumo_webhook_events` — audit log for the partner webhook

All tables have row-level security; users can only read/write their own
rows. Service role is required for webhook writes.

## Deployment

Pushes to `main` auto-deploy via Vercel. The custom domain `elevra.app`
points at the production deployment. See `docs/custom-domain.md` for
domain setup details.

## License

Proprietary.
