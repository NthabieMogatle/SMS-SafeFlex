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
  plan_tier        text not null default 'free',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Bring older deployments up to date if profiles was created before
-- plan_tier existed. Safe to re-run.
alter table public.profiles add column if not exists plan_tier text not null default 'free';

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
-- rate_limits: per-user, per-bucket request log used by
-- lib/rate-limit.ts to cap LLM-backed endpoint calls.
--   Rows are inserted on every accepted request and counted within a
--   rolling window to enforce a per-user budget. Cleanup is the caller's
--   responsibility — schedule a daily pg_cron / Supabase cron job:
--     delete from public.rate_limits where created_at < now() - interval '7 days';
-- =============================================================
create table if not exists public.rate_limits (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  bucket     text not null,
  created_at timestamptz not null default now()
);

create index if not exists rate_limits_user_bucket_created_at_idx
  on public.rate_limits(user_id, bucket, created_at desc);

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
alter table public.profiles    enable row level security;
alter table public.interviews  enable row level security;
alter table public.rate_limits enable row level security;

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

drop policy if exists "rate_limits_select_own" on public.rate_limits;
drop policy if exists "rate_limits_insert_own" on public.rate_limits;
create policy "rate_limits_select_own" on public.rate_limits
  for select using (auth.uid() = user_id);
create policy "rate_limits_insert_own" on public.rate_limits
  for insert with check (auth.uid() = user_id);

-- =============================================================
-- appsumo_webhook_events: append-only log of inbound AppSumo
-- webhook deliveries (written by app/api/webhooks/appsumo/route.ts).
-- RLS is enabled below; no policy is defined because only the
-- service_role writes/reads this table, and service_role bypasses RLS.
-- signature_ok has no default — every insert must set it explicitly.
-- =============================================================
create table if not exists public.appsumo_webhook_events (
  id            uuid primary key default gen_random_uuid(),
  event_type    text not null,
  license_key   text,
  email         text,
  payload       jsonb not null,
  signature_ok  boolean not null,
  created_at    timestamptz not null default now()
);

create index if not exists appsumo_events_email_idx
  on public.appsumo_webhook_events (email);
create index if not exists appsumo_events_license_idx
  on public.appsumo_webhook_events (license_key);

-- =============================================================
-- redemption_codes: one row per AppSumo code that can be redeemed
-- for a plan upgrade. `code` is the natural primary key. On user
-- delete, redemptions unlink (set null) rather than the row dropping.
-- =============================================================
create table if not exists public.redemption_codes (
  code         text primary key,
  plan_tier    text not null check (plan_tier in ('free','lifetime')),
  source       text,
  redeemed_by  uuid references auth.users(id) on delete set null,
  redeemed_at  timestamptz,
  created_at   timestamptz not null default now()
);

-- =============================================================
-- RLS for the AppSumo tables
-- =============================================================
alter table public.appsumo_webhook_events enable row level security;
alter table public.redemption_codes       enable row level security;

-- appsumo_webhook_events: intentionally no policies — service_role
-- bypasses RLS by design, and no other role should see these rows.

drop policy if exists "redemption_codes_select_own" on public.redemption_codes;
create policy "redemption_codes_select_own" on public.redemption_codes
  for select using (auth.uid() = redeemed_by);

-- =============================================================
-- redeem_code(p_code): atomically claim a redemption code for the
-- caller and apply the plan tier to their profile. SECURITY DEFINER
-- so it can write through RLS on profiles and redemption_codes.
-- Callable by anon/authenticated/postgres/service_role per the
-- default Supabase EXECUTE grants on public functions.
-- =============================================================
create or replace function public.redeem_code(p_code text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_tier    text;
begin
  if v_user_id is null then
    raise exception 'unauthenticated';
  end if;

  update public.redemption_codes
  set redeemed_by = v_user_id,
      redeemed_at = now()
  where upper(trim(code)) = upper(trim(p_code))
    and redeemed_by is null
  returning plan_tier into v_tier;

  if v_tier is null then
    raise exception 'invalid_or_used_code';
  end if;

  -- Upsert profile. If onboarding hasn't happened yet, create a
  -- pending-onboarding row with placeholder values that satisfy
  -- the CHECK constraints. The onboarding flow will overwrite these.
  insert into public.profiles (user_id, target_role, industry, experience_level, plan_tier)
  values (v_user_id, 'pending', 'pending', 'entry', v_tier)
  on conflict (user_id)
  do update set plan_tier = excluded.plan_tier, updated_at = now();

  return v_tier;
end;
$$;
