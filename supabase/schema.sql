-- Career OS — initial schema
-- Run once in Supabase Dashboard → SQL Editor → "New query" → paste → Run.
-- Idempotent: safe to re-run; uses IF NOT EXISTS / OR REPLACE everywhere.

-- =============================================================
-- profiles: one row per user, captures setup answers
-- =============================================================
create table if not exists public.profiles (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  target_role      text not null,
  industry         text not null,
  experience_level text not null check (experience_level in ('entry','mid','senior')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- =============================================================
-- interviews: one row per mock interview session
--   questions:        string[]              e.g. ["Tell me about...","..."]
--   answers:          string[]              user-typed answers, same order
--   feedback:         FeedbackItem[]        Claude's scored report
--   themes:           string[]              top coaching themes (nullable)
--   score:            overall avg (0-10)
--   role/industry/experience_level: snapshot of the profile config used
--     for this interview. Kept on the row so feedback/dashboard pages can
--     show the config without re-joining profiles, and so the Q1
--     anti-repetition lookup in /api/generate-questions can read prior Q1s
--     for the current user.
-- =============================================================
create table if not exists public.interviews (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  role             text,
  industry         text,
  experience_level text,
  questions        jsonb not null,
  answers          jsonb,
  feedback         jsonb,
  themes           jsonb,
  score            numeric(4,2),
  created_at       timestamptz not null default now()
);

-- Bring older deployments up to date if the table already exists without
-- these columns. Safe to re-run.
alter table public.interviews add column if not exists role             text;
alter table public.interviews add column if not exists industry         text;
alter table public.interviews add column if not exists experience_level text;
alter table public.interviews add column if not exists themes           jsonb;

create index if not exists interviews_user_id_created_at_idx
  on public.interviews(user_id, created_at desc);

-- =============================================================
-- updated_at trigger for profiles
-- =============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- =============================================================
-- Row Level Security — users can only see/edit their own rows
-- =============================================================
alter table public.profiles   enable row level security;
alter table public.interviews enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = user_id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = user_id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = user_id);

drop policy if exists "interviews_select_own" on public.interviews;
drop policy if exists "interviews_insert_own" on public.interviews;
drop policy if exists "interviews_update_own" on public.interviews;
create policy "interviews_select_own" on public.interviews
  for select using (auth.uid() = user_id);
create policy "interviews_insert_own" on public.interviews
  for insert with check (auth.uid() = user_id);
create policy "interviews_update_own" on public.interviews
  for update using (auth.uid() = user_id);
