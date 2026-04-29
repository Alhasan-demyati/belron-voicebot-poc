-- 0001_reference.sql
-- Reference data: branches, services, slot capacity rules
-- These tables are written rarely; read by every UC2/UC3 conversation.

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- ─────────────────────────────────────────────────────────────────────────────
-- branches
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.branches (
    id              uuid primary key default gen_random_uuid(),
    tenant_id       text not null default 'DE',
    code            text not null unique,
    name            text not null,
    address_line1   text not null,
    postal_code     text not null,
    city            text not null,
    country         text not null default 'DE',
    lat             numeric(9,6),
    lng             numeric(9,6),
    phone           text,
    services        text[] not null default '{}',
    active          boolean not null default true,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index if not exists idx_branches_city on public.branches (city);
create index if not exists idx_branches_postal_code on public.branches (postal_code);
create index if not exists idx_branches_active on public.branches (active);

-- ─────────────────────────────────────────────────────────────────────────────
-- branch_hours (weekly schedule)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.branch_hours (
    id           uuid primary key default gen_random_uuid(),
    branch_id    uuid not null references public.branches(id) on delete cascade,
    day_of_week  smallint not null check (day_of_week between 0 and 6),  -- 0=Mon, 6=Sun (ISO)
    opens_at     time,
    closes_at    time,
    is_closed    boolean not null default false,
    created_at   timestamptz not null default now(),
    unique (branch_id, day_of_week)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- branch_holidays
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.branch_holidays (
    id          uuid primary key default gen_random_uuid(),
    branch_id   uuid not null references public.branches(id) on delete cascade,
    date        date not null,
    reason      text,
    created_at  timestamptz not null default now(),
    unique (branch_id, date)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- services (Frontscheibe ersetzen, Reparatur, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.services (
    id                        uuid primary key default gen_random_uuid(),
    code                      text not null unique,
    name_de                   text not null,
    name_en                   text not null,
    default_duration_minutes  integer not null default 90,
    requires_calibration      boolean not null default false,
    active                    boolean not null default true,
    created_at                timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- slot_templates (recurring weekly capacity per branch+service)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.slot_templates (
    id           uuid primary key default gen_random_uuid(),
    branch_id    uuid not null references public.branches(id) on delete cascade,
    service_id   uuid not null references public.services(id) on delete cascade,
    day_of_week  smallint not null check (day_of_week between 0 and 6),
    start_time   time not null,
    end_time     time not null,
    bays         smallint not null default 1 check (bays > 0),
    created_at   timestamptz not null default now()
);

create index if not exists idx_slot_templates_branch_service
    on public.slot_templates (branch_id, service_id, day_of_week);

-- ─────────────────────────────────────────────────────────────────────────────
-- slot_overrides (manual closures, blocks, special capacity windows)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.slot_overrides (
    id              uuid primary key default gen_random_uuid(),
    branch_id       uuid not null references public.branches(id) on delete cascade,
    starts_at       timestamptz not null,
    ends_at         timestamptz not null,
    bays_available  smallint not null default 0,
    reason          text,
    created_at      timestamptz not null default now(),
    check (ends_at > starts_at)
);

create index if not exists idx_slot_overrides_branch_window
    on public.slot_overrides (branch_id, starts_at, ends_at);
