-- 0005_agent_ops.sql
-- Agent versioning + dashboard users.

-- ─────────────────────────────────────────────────────────────────────────────
-- agent_versions
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.agent_versions (
    id              uuid primary key default gen_random_uuid(),
    version         text not null unique,                    -- semver string, e.g. "0.1.0"
    system_prompt   text not null,
    model           text not null,
    temperature     numeric(3,2) not null default 0.30,
    tool_schema     jsonb,
    voice_id        text,
    notes           text,
    deployed_at     timestamptz not null default now(),
    deployed_by     uuid,
    is_active       boolean not null default false
);

create index if not exists idx_agent_versions_active on public.agent_versions (is_active) where is_active;

-- Backfill the soft FK from conversations → agent_versions
alter table public.conversations
    drop constraint if exists conversations_agent_version_fk;
alter table public.conversations
    add constraint conversations_agent_version_fk
    foreign key (agent_version_id) references public.agent_versions(id) on delete set null;

-- ─────────────────────────────────────────────────────────────────────────────
-- prompt_experiments
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.prompt_experiments (
    id             uuid primary key default gen_random_uuid(),
    name           text not null,
    variant_a_id   uuid not null references public.agent_versions(id) on delete restrict,
    variant_b_id   uuid not null references public.agent_versions(id) on delete restrict,
    traffic_split  numeric(3,2) not null default 0.50 check (traffic_split between 0 and 1),
    started_at     timestamptz not null default now(),
    ended_at       timestamptz,
    notes          text
);

-- ─────────────────────────────────────────────────────────────────────────────
-- dashboard_users (mirrors auth.users with role metadata)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.dashboard_users (
    id            uuid primary key,                         -- = auth.users.id
    email         text not null unique,
    role          text not null default 'analyst' check (role in ('admin','supervisor','analyst')),
    display_name  text,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);
