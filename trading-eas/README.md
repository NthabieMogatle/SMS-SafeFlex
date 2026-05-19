# trading-eas

MetaTrader 5 Expert Advisors and related trading artifacts.

## Contents

- `BreakoutPA_EA_MT5_v5.mq5` — Breakout price-action EA (MT5)

Additional EAs (JojosSMC, Deriv variants) will be imported here in future commits.

## Relationship to the rest of this repository

**None.** This directory is completely unrelated to the Next.js web application
(elevra.app / career-os) that lives in the rest of this repository. The two
codebases share a git repo for historical convenience only:

- No web-app code imports from or references anything in `trading-eas/`.
- No EA code imports from or references anything in the web app.
- This directory is excluded from Vercel builds via `.vercelignore`.

## Working in this directory

If you are working on the EAs, you should only touch files inside
`trading-eas/`. If you are working on the web app, you should not read, edit,
or reference any file in this directory. See `/CLAUDE.md` at the repo root for
the full guardrail.
