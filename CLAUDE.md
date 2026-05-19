# Repository guardrails

This repository contains two completely unrelated projects that share a git
repo for historical reasons only:

1. **The elevra.app / career-os Next.js web application** — everything at the
   repo root except `trading-eas/` (i.e. `app/`, `lib/`, `components/`,
   `hooks/`, `supabase/`, `public/`, `docs/`, `middleware.ts`, config files,
   etc.).
2. **MetaTrader 5 Expert Advisors** — everything inside `trading-eas/`.

There is no shared code, no shared tooling, and no cross-references between
the two. Treat them as separate repositories that happen to live in the same
working tree.

## When working on the web app (elevra.app / career-os)

`/trading-eas/` is off-limits. Do not read, edit, or reference files in that
directory.

## When working on the MT5 EAs

`/trading-eas/` is the only directory you should touch. Do not read, edit, or
reference files outside it.
