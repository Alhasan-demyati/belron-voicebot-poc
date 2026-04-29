-- Carglass DE Voicebot POC — combined migrations + seed
-- Paste this entire file into the Supabase SQL editor and click Run.
-- Generated Sun Apr 26 15:52:43 +03 2026

-- ──────────────────────────────────────────────────
-- File: migrations/0001_reference.sql
-- ──────────────────────────────────────────────────
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

-- ──────────────────────────────────────────────────
-- File: migrations/0002_operational.sql
-- ──────────────────────────────────────────────────
-- 0002_operational.sql
-- Operational data: customers, vehicles, appointments
-- Powers UC2 (status check) and UC3 (rescheduling).

-- ─────────────────────────────────────────────────────────────────────────────
-- customers
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.customers (
    id                         uuid primary key default gen_random_uuid(),
    tenant_id                  text not null default 'DE',
    phone_e164                 text,            -- E.164 format, e.g. +49301234567
    email                      text,
    first_name                 text,
    last_name                  text,
    postal_code                text,
    language                   text not null default 'de',
    consent_recording          boolean not null default false,
    consent_data_processing    boolean not null default false,
    consent_marketing          boolean not null default false,
    created_at                 timestamptz not null default now(),
    updated_at                 timestamptz not null default now()
);

create index if not exists idx_customers_phone_e164 on public.customers (phone_e164);
create index if not exists idx_customers_email on public.customers (email);
create index if not exists idx_customers_name_postal
    on public.customers using gin ((first_name || ' ' || last_name || ' ' || coalesce(postal_code, '')) gin_trgm_ops);

-- ─────────────────────────────────────────────────────────────────────────────
-- vehicles
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.vehicles (
    id              uuid primary key default gen_random_uuid(),
    customer_id     uuid not null references public.customers(id) on delete cascade,
    license_plate   text not null,
    make            text,
    model           text,
    year            smallint,
    vin             text,
    glass_type      text check (glass_type in ('windshield','side','rear','panoramic') or glass_type is null),
    notes           text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index if not exists idx_vehicles_license_plate on public.vehicles (upper(license_plate));
create index if not exists idx_vehicles_customer on public.vehicles (customer_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- appointments
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
    if not exists (select 1 from pg_type where typname = 'appointment_status') then
        create type appointment_status as enum (
            'scheduled',
            'checked_in',
            'in_progress',
            'ready_for_pickup',
            'completed',
            'cancelled',
            'no_show'
        );
    end if;
end$$;

create table if not exists public.appointments (
    id                  uuid primary key default gen_random_uuid(),
    booking_reference   text not null unique,            -- short human-readable code, e.g. CG-7K9F2
    customer_id         uuid not null references public.customers(id) on delete restrict,
    vehicle_id          uuid references public.vehicles(id) on delete set null,
    branch_id           uuid not null references public.branches(id) on delete restrict,
    service_id          uuid not null references public.services(id) on delete restrict,
    scheduled_start     timestamptz not null,
    scheduled_end       timestamptz not null,
    status              appointment_status not null default 'scheduled',
    eta_ready_at        timestamptz,
    insurance_provider  text,
    insurance_excess_eur numeric(8,2),
    notes               text,
    created_via         text not null default 'web' check (created_via in ('web','phone','bot','agent')),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    check (scheduled_end > scheduled_start)
);

create index if not exists idx_appointments_customer on public.appointments (customer_id);
create index if not exists idx_appointments_branch on public.appointments (branch_id);
create index if not exists idx_appointments_scheduled_start on public.appointments (scheduled_start);
create index if not exists idx_appointments_status on public.appointments (status);

-- ─────────────────────────────────────────────────────────────────────────────
-- appointment_history (audit trail; one row per status / time change)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.appointment_history (
    id                  uuid primary key default gen_random_uuid(),
    appointment_id      uuid not null references public.appointments(id) on delete cascade,
    previous_status     appointment_status,
    new_status          appointment_status,
    previous_start      timestamptz,
    new_start           timestamptz,
    changed_by          text not null check (changed_by in ('bot','agent','customer','system')),
    conversation_id     uuid,                            -- soft FK; conversations table created later
    reason              text,
    created_at          timestamptz not null default now()
);

create index if not exists idx_appointment_history_appt on public.appointment_history (appointment_id);
create index if not exists idx_appointment_history_conv on public.appointment_history (conversation_id);

-- ──────────────────────────────────────────────────
-- File: migrations/0003_telemetry.sql
-- ──────────────────────────────────────────────────
-- 0003_telemetry.sql
-- Telemetry: calls, conversations, turns, tool_calls, handovers, outcomes, customer_feedback
-- This is the heart of POC measurement.

-- ─────────────────────────────────────────────────────────────────────────────
-- calls (one row per phone call)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.calls (
    id                   uuid primary key default gen_random_uuid(),
    external_call_id     text unique,                    -- ElevenLabs conversation/call sid
    phone_e164_spoken    text,                           -- the number the caller spoke during identification
    phone_e164_ani       text,                           -- reserved for future telephony / caller-ID; unused at POC start
    entry_point          text,
    started_at           timestamptz not null default now(),
    ended_at             timestamptz,
    duration_seconds     integer,
    customer_id          uuid references public.customers(id) on delete set null,
    language_detected    text,
    consent_recorded     boolean not null default false,
    recording_url        text,
    created_at           timestamptz not null default now()
);

create index if not exists idx_calls_started_at on public.calls (started_at desc);
create index if not exists idx_calls_customer on public.calls (customer_id);
create index if not exists idx_calls_phone_spoken on public.calls (phone_e164_spoken);

-- ─────────────────────────────────────────────────────────────────────────────
-- conversations (1:1 with calls today; kept separate for future channels)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
    if not exists (select 1 from pg_type where typname = 'conversation_status') then
        create type conversation_status as enum (
            'in_progress',
            'completed_automated',
            'completed_with_handover',
            'abandoned'
        );
    end if;
end$$;

create table if not exists public.conversations (
    id                  uuid primary key default gen_random_uuid(),
    call_id             uuid not null references public.calls(id) on delete cascade,
    agent_version_id    uuid,                            -- soft FK to agent_versions (created later)
    language            text not null default 'de',
    status              conversation_status not null default 'in_progress',
    primary_use_case    smallint check (primary_use_case between 1 and 4),
    goal_achieved       boolean,
    final_intent        text,
    started_at          timestamptz not null default now(),
    ended_at            timestamptz,
    created_at          timestamptz not null default now()
);

create index if not exists idx_conversations_status on public.conversations (status);
create index if not exists idx_conversations_call on public.conversations (call_id);
create index if not exists idx_conversations_started_at on public.conversations (started_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- conversation_turns (every utterance; powers Realtime live-transcript view)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.conversation_turns (
    id                  uuid primary key default gen_random_uuid(),
    conversation_id     uuid not null references public.conversations(id) on delete cascade,
    turn_index          integer not null,
    role                text not null check (role in ('user','agent','system')),
    text                text,
    audio_url           text,
    latency_ms          integer,
    detected_intent     text,
    intent_confidence   numeric(4,3),
    created_at          timestamptz not null default now(),
    unique (conversation_id, turn_index)
);

create index if not exists idx_turns_conv_created on public.conversation_turns (conversation_id, created_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- tool_calls (every tool the agent invoked)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.tool_calls (
    id                  uuid primary key default gen_random_uuid(),
    conversation_id     uuid not null references public.conversations(id) on delete cascade,
    turn_id             uuid references public.conversation_turns(id) on delete set null,
    tool_name           text not null,
    request_payload     jsonb,
    response_payload    jsonb,
    status              text not null default 'success' check (status in ('success','error','timeout')),
    latency_ms          integer,
    error_message       text,
    created_at          timestamptz not null default now()
);

create index if not exists idx_tool_calls_conv on public.tool_calls (conversation_id, created_at);
create index if not exists idx_tool_calls_tool on public.tool_calls (tool_name);
create index if not exists idx_tool_calls_status on public.tool_calls (status);

-- ─────────────────────────────────────────────────────────────────────────────
-- handovers (escalation to human agent)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.handovers (
    id                       uuid primary key default gen_random_uuid(),
    conversation_id          uuid not null references public.conversations(id) on delete cascade,
    reason_code              text not null,                -- location_change | out_of_scope | customer_request | low_confidence | repeated_failure | other
    summary_for_agent        text not null,
    customer_data_snapshot   jsonb,
    qualified                boolean not null default false,
    transferred_to           text,
    created_at               timestamptz not null default now()
);

create index if not exists idx_handovers_conv on public.handovers (conversation_id);
create index if not exists idx_handovers_reason on public.handovers (reason_code);

-- ─────────────────────────────────────────────────────────────────────────────
-- outcomes (per-conversation rollup, refreshed on call end)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.outcomes (
    id                          uuid primary key default gen_random_uuid(),
    conversation_id             uuid not null unique references public.conversations(id) on delete cascade,
    use_case                    smallint check (use_case between 1 and 4),
    automated                   boolean not null default false,
    abandoned                   boolean not null default false,
    abandonment_stage           text check (abandonment_stage in ('intent_detection','identification','search','confirmation','other') or abandonment_stage is null),
    handover                    boolean not null default false,
    handover_qualified          boolean,
    aht_seconds                 integer,
    time_to_first_response_ms   integer,
    tool_calls_count            integer not null default 0,
    tool_call_failures          integer not null default 0,
    customer_goal_completed     boolean,
    recomputed_at               timestamptz not null default now()
);

create index if not exists idx_outcomes_use_case on public.outcomes (use_case);
create index if not exists idx_outcomes_automated on public.outcomes (automated);
create index if not exists idx_outcomes_recomputed on public.outcomes (recomputed_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- customer_feedback (in-call CES, 1–10)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.customer_feedback (
    id                uuid primary key default gen_random_uuid(),
    conversation_id   uuid not null unique references public.conversations(id) on delete cascade,
    ces_score         smallint check (ces_score between 1 and 10),
    ces_collected     boolean not null default false,
    ces_question      text,
    comment_text      text,
    source            text not null default 'in_call' check (source in ('in_call','agent_followup')),
    created_at        timestamptz not null default now()
);

create index if not exists idx_feedback_collected on public.customer_feedback (ces_collected);
create index if not exists idx_feedback_score on public.customer_feedback (ces_score);

-- ─────────────────────────────────────────────────────────────────────────────
-- agent_quality_feedback (human-agent rating of handover quality)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.agent_quality_feedback (
    id                       uuid primary key default gen_random_uuid(),
    conversation_id          uuid not null references public.conversations(id) on delete cascade,
    handover_id              uuid references public.handovers(id) on delete set null,
    quality_score            smallint check (quality_score between 1 and 5),
    was_qualified            boolean,
    would_have_self_served   boolean,
    notes                    text,
    agent_user_id            uuid,
    created_at               timestamptz not null default now()
);

create index if not exists idx_aqf_conv on public.agent_quality_feedback (conversation_id);

-- ──────────────────────────────────────────────────
-- File: migrations/0004_governance.sql
-- ──────────────────────────────────────────────────
-- 0004_governance.sql
-- Governance / safety / API reliability tracking.
-- Drives the >99% integration-reliability KPI and the safety-events page.

-- ─────────────────────────────────────────────────────────────────────────────
-- consent_events
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.consent_events (
    id              uuid primary key default gen_random_uuid(),
    call_id         uuid not null references public.calls(id) on delete cascade,
    consent_type    text not null check (consent_type in ('recording','data_processing','marketing')),
    granted         boolean not null,
    prompt_text     text,
    response_text   text,
    created_at      timestamptz not null default now()
);

create index if not exists idx_consent_call on public.consent_events (call_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- safety_events (guardrail trips: hallucination, PII, out-of-scope, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.safety_events (
    id                uuid primary key default gen_random_uuid(),
    conversation_id   uuid references public.conversations(id) on delete cascade,
    event_type        text not null check (event_type in (
                          'hallucination_suspect',
                          'pii_leakage',
                          'out_of_scope',
                          'prompt_injection',
                          'unsafe_topic',
                          'tool_failure',
                          'other'
                      )),
    detector          text not null check (detector in ('rule','llm_judge','manual')),
    severity          text not null default 'info' check (severity in ('info','warning','error','critical')),
    action_taken      text check (action_taken in ('warned','redacted','escalated','no_action')),
    details           jsonb,
    acknowledged_at   timestamptz,
    acknowledged_by   uuid,
    created_at        timestamptz not null default now()
);

create index if not exists idx_safety_conv on public.safety_events (conversation_id);
create index if not exists idx_safety_severity on public.safety_events (severity);
create index if not exists idx_safety_unacked on public.safety_events (acknowledged_at) where acknowledged_at is null;

-- ─────────────────────────────────────────────────────────────────────────────
-- integration_health (drives the >99% API reliability KPI)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.integration_health (
    id               uuid primary key default gen_random_uuid(),
    integration      text not null check (integration in ('crm','booking','telephony','elevenlabs','n8n','other')),
    endpoint         text,
    status_code      integer,
    latency_ms       integer,
    success          boolean not null,
    conversation_id  uuid references public.conversations(id) on delete set null,
    error_message    text,
    created_at       timestamptz not null default now()
);

create index if not exists idx_int_health_int_created on public.integration_health (integration, created_at desc);
create index if not exists idx_int_health_success on public.integration_health (success, created_at desc);

-- ──────────────────────────────────────────────────
-- File: migrations/0005_agent_ops.sql
-- ──────────────────────────────────────────────────
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

-- ──────────────────────────────────────────────────
-- File: migrations/0006_indexes_and_rls.sql
-- ──────────────────────────────────────────────────
-- 0006_indexes_and_rls.sql
-- Row-Level Security: dashboard users (anon/authenticated) get read-only on
-- everything; service_role (n8n) bypasses RLS entirely. Writes from the
-- dashboard go through service-role-protected RPC functions only where needed.

-- ─────────────────────────────────────────────────────────────────────────────
-- Enable RLS on all public tables
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.branches              enable row level security;
alter table public.branch_hours          enable row level security;
alter table public.branch_holidays       enable row level security;
alter table public.services              enable row level security;
alter table public.slot_templates        enable row level security;
alter table public.slot_overrides        enable row level security;
alter table public.customers             enable row level security;
alter table public.vehicles              enable row level security;
alter table public.appointments          enable row level security;
alter table public.appointment_history   enable row level security;
alter table public.calls                 enable row level security;
alter table public.conversations         enable row level security;
alter table public.conversation_turns    enable row level security;
alter table public.tool_calls            enable row level security;
alter table public.handovers             enable row level security;
alter table public.outcomes              enable row level security;
alter table public.customer_feedback     enable row level security;
alter table public.agent_quality_feedback enable row level security;
alter table public.consent_events        enable row level security;
alter table public.safety_events         enable row level security;
alter table public.integration_health    enable row level security;
alter table public.agent_versions        enable row level security;
alter table public.prompt_experiments    enable row level security;
alter table public.dashboard_users       enable row level security;

-- ─────────────────────────────────────────────────────────────────────────────
-- Authenticated dashboard users: read everything
-- (Role-based filtering is enforced at the app layer for now; admin-only writes
-- happen via service_role from server actions.)
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare t text;
begin
    foreach t in array array[
        'branches','branch_hours','branch_holidays','services','slot_templates','slot_overrides',
        'customers','vehicles','appointments','appointment_history',
        'calls','conversations','conversation_turns','tool_calls',
        'handovers','outcomes','customer_feedback','agent_quality_feedback',
        'consent_events','safety_events','integration_health',
        'agent_versions','prompt_experiments','dashboard_users'
    ]
    loop
        execute format(
            'drop policy if exists "authenticated read %1$I" on public.%1$I',
            t
        );
        execute format(
            'create policy "authenticated read %1$I" on public.%1$I '
            'for select to authenticated using (true)',
            t
        );
    end loop;
end$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- dashboard_users: a user can update their own profile row
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "self update dashboard_users" on public.dashboard_users;
create policy "self update dashboard_users" on public.dashboard_users
    for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "self insert dashboard_users" on public.dashboard_users;
create policy "self insert dashboard_users" on public.dashboard_users
    for insert to authenticated with check (id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- safety_events: supervisors / admins can ack
-- (Filtering by role is checked at the route layer — this just gates UPDATE.)
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "authenticated ack safety_events" on public.safety_events;
create policy "authenticated ack safety_events" on public.safety_events
    for update to authenticated using (true) with check (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- agent_quality_feedback: an authenticated agent can insert their own row
-- ─────────────────────────────────────────────────────────────────────────────
drop policy if exists "authenticated insert agent_quality_feedback" on public.agent_quality_feedback;
create policy "authenticated insert agent_quality_feedback" on public.agent_quality_feedback
    for insert to authenticated with check (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- service_role bypasses RLS by default; n8n uses the service role key.
-- No additional policies needed for write access from n8n.
-- ─────────────────────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime: enable for live transcript + live calls
-- ─────────────────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_turns;
alter publication supabase_realtime add table public.tool_calls;
alter publication supabase_realtime add table public.outcomes;
alter publication supabase_realtime add table public.safety_events;

-- ──────────────────────────────────────────────────
-- File: migrations/0007_kpi_views.sql
-- ──────────────────────────────────────────────────
-- 0007_kpi_views.sql
-- KPI views aligned to the POC measurement framework.
-- POC targets: UC1 70%, UC2 80%, UC3 40% automation; <8.7% abandonment;
-- >99% integration reliability; CES 1–10.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) Automation rate per use case
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_automation_by_usecase as
select
    o.use_case,
    count(*)                                                       as total_calls,
    count(*) filter (where o.automated)                            as automated_calls,
    case when count(*) = 0 then null
         else round(100.0 * count(*) filter (where o.automated) / count(*), 2)
    end                                                            as automation_rate_pct,
    count(*) filter (where o.handover)                             as handover_calls,
    count(*) filter (where o.abandoned)                            as abandoned_calls
from public.outcomes o
where o.use_case is not null
group by o.use_case
order by o.use_case;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) Abandonment funnel (where do we lose people?)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_abandonment_funnel as
select
    coalesce(o.abandonment_stage, 'unknown')   as stage,
    count(*)                                   as count,
    o.use_case
from public.outcomes o
where o.abandoned
group by o.abandonment_stage, o.use_case
order by o.use_case, count desc;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) Handover quality: qualified vs unqualified, with avg agent score
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_handover_quality as
select
    h.reason_code,
    count(*)                                                            as total,
    count(*) filter (where h.qualified)                                 as qualified,
    case when count(*) = 0 then null
         else round(100.0 * count(*) filter (where h.qualified) / count(*), 2)
    end                                                                 as qualified_pct,
    avg(aqf.quality_score)::numeric(3,2)                                as avg_agent_score
from public.handovers h
left join public.agent_quality_feedback aqf on aqf.handover_id = h.id
group by h.reason_code
order by total desc;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) AHT distribution (p50/p90/p99) per UC
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_aht_distribution as
select
    o.use_case,
    count(*)                                                         as samples,
    percentile_cont(0.50) within group (order by o.aht_seconds)::int as p50_seconds,
    percentile_cont(0.90) within group (order by o.aht_seconds)::int as p90_seconds,
    percentile_cont(0.99) within group (order by o.aht_seconds)::int as p99_seconds,
    avg(o.aht_seconds)::int                                          as avg_seconds
from public.outcomes o
where o.aht_seconds is not null and o.use_case is not null
group by o.use_case
order by o.use_case;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5) Integration reliability (>99% target line)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_integration_reliability as
select
    integration,
    date_trunc('day', created_at)::date    as day,
    count(*)                               as total_calls,
    count(*) filter (where success)        as successful_calls,
    case when count(*) = 0 then null
         else round(100.0 * count(*) filter (where success) / count(*), 3)
    end                                    as success_rate_pct,
    avg(latency_ms)::int                   as avg_latency_ms,
    percentile_cont(0.95) within group (order by latency_ms)::int as p95_latency_ms
from public.integration_health
group by integration, day
order by day desc, integration;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6) CES — average per UC, weekly trend
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_ces_avg_by_usecase as
select
    o.use_case,
    date_trunc('week', cf.created_at)::date as week,
    count(cf.ces_score)                     as ratings,
    avg(cf.ces_score)::numeric(4,2)         as avg_ces,
    min(cf.ces_score)                       as min_ces,
    max(cf.ces_score)                       as max_ces
from public.customer_feedback cf
join public.outcomes o on o.conversation_id = cf.conversation_id
where cf.ces_collected
group by o.use_case, week
order by week desc, o.use_case;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7) CES distribution (histogram across 1..10 per UC)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_ces_distribution as
select
    o.use_case,
    cf.ces_score,
    count(*) as count
from public.customer_feedback cf
join public.outcomes o on o.conversation_id = cf.conversation_id
where cf.ces_collected
group by o.use_case, cf.ces_score
order by o.use_case, cf.ces_score;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8) CES capture rate (% of completed calls where a rating was actually given)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_ces_capture_rate as
select
    date_trunc('day', cf.created_at)::date as day,
    count(*)                               as total_feedback_rows,
    count(*) filter (where cf.ces_collected) as collected,
    case when count(*) = 0 then null
         else round(100.0 * count(*) filter (where cf.ces_collected) / count(*), 2)
    end                                    as capture_rate_pct
from public.customer_feedback cf
group by day
order by day desc;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9) Velocity — agent_versions deployed per week (proxy for change velocity)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_velocity_changelog as
select
    date_trunc('week', deployed_at)::date  as week,
    count(*)                               as versions_deployed,
    array_agg(version order by deployed_at) as versions
from public.agent_versions
group by week
order by week desc;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10) Overview rollup (single-row card data for the dashboard home)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace view public.kpi_overview as
select
    (select count(*) from public.conversations where status = 'in_progress')                  as live_calls,
    (select count(*) from public.outcomes)                                                    as total_calls_with_outcome,
    (select round(100.0 * count(*) filter (where automated) / nullif(count(*), 0), 2)
       from public.outcomes)                                                                  as overall_automation_pct,
    (select round(100.0 * count(*) filter (where abandoned) / nullif(count(*), 0), 2)
       from public.outcomes)                                                                  as overall_abandonment_pct,
    (select round(100.0 * count(*) filter (where handover_qualified) /
                         nullif(count(*) filter (where handover), 0), 2)
       from public.outcomes)                                                                  as qualified_handover_pct,
    (select round(avg(ces_score)::numeric, 2)
       from public.customer_feedback where ces_collected)                                     as avg_ces_overall,
    (select round(100.0 * count(*) filter (where ces_collected) / nullif(count(*), 0), 2)
       from public.customer_feedback)                                                         as ces_capture_pct,
    (select round(100.0 * count(*) filter (where success) / nullif(count(*), 0), 3)
       from public.integration_health
       where created_at > now() - interval '7 days')                                          as integration_reliability_7d_pct;

-- ──────────────────────────────────────────────────
-- File: migrations/0008_booking_intake.sql
-- ──────────────────────────────────────────────────
-- 0008_booking_intake.sql
-- Adds damage intake fields captured during the new-booking voice flow (UC5).
-- Allows vehicle rows without a license plate (callers are not asked for one
-- in the new-booking flow).

do $$
begin
    if not exists (select 1 from pg_type where typname = 'damage_size') then
        create type damage_size as enum ('small', 'medium', 'large');
    end if;
end$$;

alter table public.appointments
    add column if not exists damage_size  damage_size,
    add column if not exists damage_notes text;

alter table public.vehicles
    alter column license_plate drop not null;

-- ──────────────────────────────────────────────────
-- File: seed.sql
-- ──────────────────────────────────────────────────
-- seed.sql
-- German mock data for the Carglass Germany Voicebot POC.
-- Run AFTER all migrations. Idempotent-ish (uses ON CONFLICT where natural keys exist;
-- truncates telemetry on re-seed for a clean slate).

begin;

-- ─────────────────────────────────────────────────────────────────────────────
-- Wipe telemetry & dependent tables for repeatable seeding
-- ─────────────────────────────────────────────────────────────────────────────
truncate table
    public.customer_feedback,
    public.outcomes,
    public.handovers,
    public.tool_calls,
    public.conversation_turns,
    public.conversations,
    public.calls,
    public.consent_events,
    public.safety_events,
    public.integration_health,
    public.appointment_history,
    public.appointments,
    public.vehicles,
    public.customers,
    public.slot_overrides,
    public.slot_templates,
    public.branch_holidays,
    public.branch_hours,
    public.branches,
    public.services,
    public.agent_quality_feedback,
    public.prompt_experiments,
    public.agent_versions
restart identity cascade;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5 services
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.services (code, name_de, name_en, default_duration_minutes, requires_calibration) values
    ('CG-FA',  'Frontscheibe ersetzen',    'Windshield replacement', 150, true),
    ('CG-FR',  'Frontscheibe reparieren',  'Windshield repair',       60, false),
    ('CG-SS',  'Seitenscheibe ersetzen',   'Side window replacement', 90, false),
    ('CG-HS',  'Heckscheibe ersetzen',     'Rear window replacement', 90, false),
    ('CG-CAL', 'Kalibrierung',             'ADAS calibration',        60, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 20 branches across major DE cities
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.branches (code, name, address_line1, postal_code, city, lat, lng, phone, services) values
    ('B-BER-01', 'Berlin Mitte',           'Friedrichstraße 100',     '10117', 'Berlin',     52.520008, 13.404954, '+493012345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-BER-02', 'Berlin Charlottenburg',  'Kantstraße 45',           '10625', 'Berlin',     52.506863, 13.317570, '+493012345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-HAM-01', 'Hamburg Altona',         'Große Bergstraße 20',     '22767', 'Hamburg',    53.550556, 9.935833,  '+494012345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-HAM-02', 'Hamburg Wandsbek',       'Wandsbeker Marktstr 10',  '22041', 'Hamburg',    53.580000, 10.080000, '+494012345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-MUC-01', 'München Schwabing',      'Leopoldstraße 75',        '80802', 'München',    48.158889, 11.583056, '+498912345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-MUC-02', 'München Pasing',         'Bäckerstraße 2',          '81241', 'München',    48.143333, 11.461667, '+498912345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-KOE-01', 'Köln Innenstadt',        'Hohe Straße 50',          '50667', 'Köln',       50.937500, 6.960278,  '+492212345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-KOE-02', 'Köln Ehrenfeld',         'Venloer Straße 200',      '50823', 'Köln',       50.951667, 6.918333,  '+492212345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-FFM-01', 'Frankfurt Innenstadt',   'Zeil 80',                 '60313', 'Frankfurt',  50.114444, 8.683056,  '+496912345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-FFM-02', 'Frankfurt Bornheim',     'Berger Straße 150',       '60385', 'Frankfurt',  50.130556, 8.706944,  '+496912345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-STU-01', 'Stuttgart Vaihingen',    'Schwabstraße 40',         '70197', 'Stuttgart',  48.766667, 9.150000,  '+497112345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-DUS-01', 'Düsseldorf Bilk',        'Bilker Allee 200',        '40217', 'Düsseldorf', 51.213889, 6.776111,  '+492112345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-LEJ-01', 'Leipzig Süd',            'Karl-Liebknecht-Str 100', '04275', 'Leipzig',    51.323889, 12.378056, '+493412345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-DTM-01', 'Dortmund Hörde',         'Hermannstraße 25',        '44263', 'Dortmund',   51.490000, 7.500000,  '+492312345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-ESS-01', 'Essen Holsterhausen',    'Gemarkenstraße 60',       '45147', 'Essen',      51.450000, 6.997500,  '+492012345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-HBR-01', 'Bremen Findorff',        'Hemmstraße 80',           '28215', 'Bremen',     53.090000, 8.795000,  '+494212345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-HAJ-01', 'Hannover Mitte',         'Georgstraße 30',          '30159', 'Hannover',   52.376111, 9.730556,  '+495112345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-NUE-01', 'Nürnberg Süd',           'Allersberger Straße 100', '90461', 'Nürnberg',   49.430000, 11.080000, '+499112345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-DRS-01', 'Dresden Neustadt',       'Hauptstraße 20',          '01097', 'Dresden',    51.061111, 13.738889, '+493512345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-BON-01', 'Bonn Bad Godesberg',     'Koblenzer Straße 50',     '53177', 'Bonn',       50.683333, 7.150000,  '+492212345003', array['CG-FA','CG-FR','CG-SS','CG-CAL']);

-- ─────────────────────────────────────────────────────────────────────────────
-- branch_hours: Mon-Fri 08:00-18:00, Sat 09:00-13:00, Sun closed
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.branch_hours (branch_id, day_of_week, opens_at, closes_at, is_closed)
select b.id, dow,
       case when dow = 5 then time '09:00' when dow = 6 then null else time '08:00' end,
       case when dow = 5 then time '13:00' when dow = 6 then null else time '18:00' end,
       (dow = 6)
from public.branches b
cross join generate_series(0, 6) as dow;

-- ─────────────────────────────────────────────────────────────────────────────
-- branch_holidays: 2026-05-01 (Tag der Arbeit) and 2026-10-03 (Tag der Deutschen Einheit)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.branch_holidays (branch_id, date, reason)
select b.id, d, r
from public.branches b
cross join (values
    (date '2026-05-01', 'Tag der Arbeit'),
    (date '2026-10-03', 'Tag der Deutschen Einheit')
) as h(d, r);

-- ─────────────────────────────────────────────────────────────────────────────
-- slot_templates: Mon-Fri 08:00-18:00 (3 bays), Sat 09:00-13:00 (2 bays); per service
-- (single all-day window keeps the math simple for the POC; n8n discretizes into
--  service-duration-sized slots at query time)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.slot_templates (branch_id, service_id, day_of_week, start_time, end_time, bays)
select b.id, s.id, dow,
       case when dow = 5 then time '09:00' else time '08:00' end,
       case when dow = 5 then time '13:00' else time '18:00' end,
       case when dow = 5 then 2 else 3 end
from public.branches b
cross join public.services s
cross join generate_series(0, 5) as dow;  -- skip Sunday (6)

-- ─────────────────────────────────────────────────────────────────────────────
-- 50 customers with German names and valid +49 phones
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.customers (
    phone_e164, email, first_name, last_name, postal_code, language,
    consent_recording, consent_data_processing, consent_marketing
) values
    ('+491701234001', 'lukas.mueller@example.de',     'Lukas',    'Müller',     '10117', 'de', true,  true,  false),
    ('+491701234002', 'anna.schmidt@example.de',      'Anna',     'Schmidt',    '20354', 'de', true,  true,  true),
    ('+491701234003', 'jonas.fischer@example.de',     'Jonas',    'Fischer',    '80331', 'de', true,  true,  false),
    ('+491701234004', 'lena.weber@example.de',        'Lena',     'Weber',      '50667', 'de', true,  true,  false),
    ('+491701234005', 'finn.meyer@example.de',        'Finn',     'Meyer',      '60311', 'de', false, true,  false),
    ('+491701234006', 'mia.wagner@example.de',        'Mia',      'Wagner',     '70173', 'de', true,  true,  true),
    ('+491701234007', 'paul.becker@example.de',       'Paul',     'Becker',     '40212', 'de', true,  true,  false),
    ('+491701234008', 'emma.schulz@example.de',       'Emma',     'Schulz',     '04109', 'de', true,  true,  false),
    ('+491701234009', 'noah.hoffmann@example.de',     'Noah',     'Hoffmann',   '44135', 'de', false, true,  false),
    ('+491701234010', 'lina.schaefer@example.de',     'Lina',     'Schäfer',    '45127', 'de', true,  true,  false),
    ('+491701234011', 'leon.koch@example.de',         'Leon',     'Koch',       '28195', 'de', true,  true,  true),
    ('+491701234012', 'hannah.bauer@example.de',      'Hannah',   'Bauer',      '30159', 'de', true,  true,  false),
    ('+491701234013', 'elias.richter@example.de',     'Elias',    'Richter',    '90402', 'de', true,  true,  false),
    ('+491701234014', 'sophie.klein@example.de',      'Sophie',   'Klein',      '01067', 'de', true,  true,  false),
    ('+491701234015', 'maximilian.wolf@example.de',   'Maximilian','Wolf',      '53111', 'de', true,  true,  true),
    ('+491701234016', 'marie.neumann@example.de',     'Marie',    'Neumann',    '10117', 'de', true,  true,  false),
    ('+491701234017', 'felix.schwarz@example.de',     'Felix',    'Schwarz',    '20354', 'de', false, true,  false),
    ('+491701234018', 'lea.zimmermann@example.de',    'Lea',      'Zimmermann', '80331', 'de', true,  true,  false),
    ('+491701234019', 'julian.braun@example.de',      'Julian',   'Braun',      '50667', 'de', true,  true,  true),
    ('+491701234020', 'laura.krueger@example.de',     'Laura',    'Krüger',     '60311', 'de', true,  true,  false),
    ('+491701234021', 'benjamin.hofmann@example.de',  'Benjamin', 'Hofmann',    '70173', 'de', true,  true,  false),
    ('+491701234022', 'klara.hartmann@example.de',    'Klara',    'Hartmann',   '40212', 'de', true,  true,  false),
    ('+491701234023', 'tim.lange@example.de',         'Tim',      'Lange',      '04109', 'de', false, true,  false),
    ('+491701234024', 'amelie.schmitt@example.de',    'Amelie',   'Schmitt',    '44135', 'de', true,  true,  true),
    ('+491701234025', 'david.werner@example.de',      'David',    'Werner',     '45127', 'de', true,  true,  false),
    ('+491701234026', 'helena.krause@example.de',     'Helena',   'Krause',     '28195', 'de', true,  true,  false),
    ('+491701234027', 'simon.lehmann@example.de',     'Simon',    'Lehmann',    '30159', 'de', true,  true,  false),
    ('+491701234028', 'pia.schulze@example.de',       'Pia',      'Schulze',    '90402', 'de', true,  true,  true),
    ('+491701234029', 'erik.maier@example.de',        'Erik',     'Maier',      '01067', 'de', true,  true,  false),
    ('+491701234030', 'fiona.koehler@example.de',     'Fiona',    'Köhler',     '53111', 'de', false, true,  false),
    ('+491701234031', 'oskar.herrmann@example.de',    'Oskar',    'Herrmann',   '22767', 'de', true,  true,  false),
    ('+491701234032', 'ida.koenig@example.de',        'Ida',      'König',      '10625', 'de', true,  true,  false),
    ('+491701234033', 'theo.walter@example.de',       'Theo',     'Walter',     '80802', 'de', true,  true,  true),
    ('+491701234034', 'mila.mayer@example.de',        'Mila',     'Mayer',      '50823', 'de', true,  true,  false),
    ('+491701234035', 'liam.huber@example.de',        'Liam',     'Huber',      '60385', 'de', true,  true,  false),
    ('+491701234036', 'frieda.kaiser@example.de',     'Frieda',   'Kaiser',     '70197', 'de', true,  true,  false),
    ('+491701234037', 'henry.fuchs@example.de',       'Henry',    'Fuchs',      '40217', 'de', false, true,  false),
    ('+491701234038', 'matilda.peters@example.de',    'Matilda',  'Peters',     '04275', 'de', true,  true,  true),
    ('+491701234039', 'anton.lang@example.de',        'Anton',    'Lang',       '44263', 'de', true,  true,  false),
    ('+491701234040', 'rosa.scholz@example.de',       'Rosa',     'Scholz',     '45147', 'de', true,  true,  false),
    ('+491701234041', 'milo.jung@example.de',         'Milo',     'Jung',       '28215', 'de', true,  true,  false),
    ('+491701234042', 'nora.hahn@example.de',         'Nora',     'Hahn',       '30159', 'de', true,  true,  false),
    ('+491701234043', 'samuel.vogel@example.de',      'Samuel',   'Vogel',      '90461', 'de', true,  true,  true),
    ('+491701234044', 'alma.friedrich@example.de',    'Alma',     'Friedrich',  '01097', 'de', true,  true,  false),
    ('+491701234045', 'aaron.keller@example.de',      'Aaron',    'Keller',     '53177', 'de', false, true,  false),
    ('+491701234046', 'isabella.guenther@example.de', 'Isabella', 'Günther',    '22041', 'de', true,  true,  false),
    ('+491701234047', 'oscar.berg@example.de',        'Oscar',    'Berg',       '81241', 'de', true,  true,  false),
    ('+491701234048', 'mathilda.frank@example.de',    'Mathilda', 'Frank',      '50823', 'de', true,  true,  true),
    ('+491701234049', 'levi.berger@example.de',       'Levi',     'Berger',     '60385', 'de', true,  true,  false),
    ('+491701234050', 'emilia.winkler@example.de',    'Emilia',   'Winkler',    '70197', 'de', true,  true,  false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 80 vehicles linked to customers (most have 1, some have 2)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.vehicles (customer_id, license_plate, make, model, year, glass_type)
select c.id,
       'B-' || upper(substring(md5(c.id::text || s::text), 1, 2)) || ' ' || (1000 + (s * 17 + 100) % 9000)::text,
       (array['VW','BMW','Mercedes','Audi','Opel','Ford','Skoda','Renault','Peugeot','Hyundai'])[1 + (abs(hashtext(c.id::text || s::text)) % 10)],
       (array['Golf','Polo','3er','5er','C-Klasse','A4','A6','Astra','Focus','Octavia','Megane','308','i30'])[1 + (abs(hashtext(c.id::text || s::text || 'm')) % 13)],
       2017 + (abs(hashtext(c.id::text || s::text || 'y')) % 8),
       (array['windshield','side','rear','panoramic'])[1 + (abs(hashtext(c.id::text || s::text || 'g')) % 4)]
from public.customers c
cross join generate_series(1, 2) as s
where s = 1 or (abs(hashtext(c.id::text)) % 100) < 60   -- ~60% of customers have a 2nd car → ~80 total
order by c.id, s;

-- ─────────────────────────────────────────────────────────────────────────────
-- Agent versions (3 versions, v0.3 active)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.agent_versions (version, system_prompt, model, temperature, voice_id, notes, deployed_at, is_active) values
    ('0.1.0',  'Baseline-Prompt v0.1 — siehe elevenlabs/system_prompt_de.md',                 'gpt-4o-mini',  0.30, 'ELEVEN-DE-FEMALE-V1', 'Initial baseline.',                       now() - interval '30 days', false),
    ('0.2.0',  'Refined-Prompt v0.2 — verbesserte Identifikation und CES-Fluss',              'gpt-4o',       0.30, 'ELEVEN-DE-FEMALE-V1', 'Improved identification and CES flow.',   now() - interval '14 days', false),
    ('0.3.0',  'Production-Prompt v0.3 — vollständiger Prompt mit allen 4 Use Cases',         'gpt-4o',       0.30, 'ELEVEN-DE-FEMALE-V2', 'Current active production prompt.',       now() - interval '2 days',  true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 150 appointments: spread −30d…+30d, varied statuses, varied branches/services
-- ─────────────────────────────────────────────────────────────────────────────
with picks as (
    select
        gs as n,
        (now() - interval '30 days' + (gs * interval '8 hours'))::timestamptz as base_start
    from generate_series(0, 149) as gs
),
joined as (
    select
        p.n,
        p.base_start,
        (select id from public.customers order by id offset (p.n % 50) limit 1) as customer_id,
        (select id from public.branches  order by id offset (p.n % 20) limit 1) as branch_id,
        (select id from public.services  order by id offset (p.n %  5) limit 1) as service_id,
        (select default_duration_minutes from public.services order by id offset (p.n % 5) limit 1) as duration_min
    from picks p
)
insert into public.appointments (
    booking_reference, customer_id, vehicle_id, branch_id, service_id,
    scheduled_start, scheduled_end, status, eta_ready_at,
    insurance_provider, insurance_excess_eur, created_via
)
select
    'CG-' || upper(substring(md5(j.n::text || j.base_start::text), 1, 5)),
    j.customer_id,
    (select id from public.vehicles v where v.customer_id = j.customer_id order by v.id limit 1),
    j.branch_id,
    j.service_id,
    j.base_start,
    j.base_start + (j.duration_min || ' minutes')::interval,
    case
        when j.base_start < now() - interval '7 days' then
            (array['completed','completed','completed','no_show','cancelled'])[1 + (j.n % 5)]::appointment_status
        when j.base_start < now() - interval '1 day' then
            (array['completed','ready_for_pickup','no_show'])[1 + (j.n % 3)]::appointment_status
        when j.base_start < now() then
            (array['in_progress','ready_for_pickup','checked_in'])[1 + (j.n % 3)]::appointment_status
        else
            (array['scheduled','scheduled','scheduled','cancelled'])[1 + (j.n % 4)]::appointment_status
    end,
    case when j.n % 7 = 0 then j.base_start + (j.duration_min + 15) * interval '1 minute' else null end,
    (array['HUK Coburg','Allianz','AXA','DEVK','LVM','R+V','Selbstzahler'])[1 + (j.n % 7)],
    case (j.n % 7)
        when 6 then null  -- Selbstzahler → no excess
        else (array[0, 150, 300]::numeric[])[1 + (j.n % 3)]
    end,
    (array['web','phone','bot','agent'])[1 + (j.n % 4)]
from joined j;

-- ─────────────────────────────────────────────────────────────────────────────
-- Synthetic telemetry so dashboard charts are populated on day one.
-- We mock 60 historical conversations across all 4 use cases with realistic
-- distributions of automated/handover/abandoned and CES scores 1–10.
-- ─────────────────────────────────────────────────────────────────────────────
with seed_calls as (
    insert into public.calls (
        external_call_id, phone_e164_spoken, started_at, ended_at, duration_seconds,
        customer_id, language_detected, consent_recorded
    )
    select
        'mock_' || gs::text,
        c.phone_e164,
        now() - (gs || ' hours')::interval,
        now() - (gs || ' hours')::interval + ((60 + (gs * 7) % 240) || ' seconds')::interval,
        60 + (gs * 7) % 240,
        c.id,
        'de',
        true
    from generate_series(1, 60) as gs
    join lateral (
        select id, phone_e164 from public.customers order by id offset (gs % 50) limit 1
    ) c on true
    returning id, external_call_id, started_at, ended_at, customer_id, duration_seconds
),
seed_convs as (
    insert into public.conversations (
        call_id, agent_version_id, language, status,
        primary_use_case, goal_achieved, started_at, ended_at
    )
    select
        sc.id,
        (select id from public.agent_versions where is_active limit 1),
        'de',
        case (cast(substring(sc.external_call_id from 6) as int) % 10)
            when 0 then 'abandoned'::conversation_status
            when 1 then 'completed_with_handover'::conversation_status
            else 'completed_automated'::conversation_status
        end,
        1 + (cast(substring(sc.external_call_id from 6) as int) % 4),
        case (cast(substring(sc.external_call_id from 6) as int) % 10)
            when 0 then false
            when 1 then false
            else true
        end,
        sc.started_at,
        sc.ended_at
    from seed_calls sc
    returning id, status, primary_use_case, started_at, ended_at, call_id
)
insert into public.outcomes (
    conversation_id, use_case, automated, abandoned, abandonment_stage,
    handover, handover_qualified, aht_seconds, time_to_first_response_ms,
    tool_calls_count, tool_call_failures, customer_goal_completed
)
select
    cv.id,
    cv.primary_use_case,
    (cv.status = 'completed_automated'),
    (cv.status = 'abandoned'),
    case when cv.status = 'abandoned' then (array['identification','search','confirmation','intent_detection'])[1 + (extract(epoch from cv.started_at)::bigint % 4)] else null end,
    (cv.status = 'completed_with_handover'),
    case when cv.status = 'completed_with_handover' then (extract(epoch from cv.started_at)::bigint % 5 < 4) else null end,
    extract(epoch from (cv.ended_at - cv.started_at))::int,
    300 + (extract(epoch from cv.started_at)::bigint % 800)::int,
    1 + (extract(epoch from cv.started_at)::bigint % 6)::int,
    case when extract(epoch from cv.started_at)::bigint % 20 = 0 then 1 else 0 end,
    (cv.status in ('completed_automated','completed_with_handover'))
from seed_convs cv;

-- Customer feedback rows: ~85% capture rate, scores skewed positive
insert into public.customer_feedback (conversation_id, ces_score, ces_collected, ces_question, source)
select
    o.conversation_id,
    case when (extract(epoch from o.recomputed_at)::bigint % 100) < 85
         then ((extract(epoch from o.recomputed_at)::bigint % 6) + 5)::smallint   -- 5..10 mostly
         else null
    end,
    ((extract(epoch from o.recomputed_at)::bigint % 100) < 85),
    'Auf einer Skala von 1 bis 10, wie würden Sie unser Gespräch heute bewerten?',
    'in_call'
from public.outcomes o;

-- A few low scores for distribution variety
update public.customer_feedback
set ces_score = ((random() * 4)::int + 1)::smallint
where ces_collected
  and id in (select id from public.customer_feedback where ces_collected order by random() limit 6);

-- Handover rows for the conversations marked completed_with_handover
insert into public.handovers (conversation_id, reason_code, summary_for_agent, qualified, transferred_to)
select
    o.conversation_id,
    (array['location_change','out_of_scope','customer_request','low_confidence','repeated_failure'])[1 + (extract(epoch from o.recomputed_at)::bigint % 5)],
    'Kunde wünscht persönliche Beratung. Bisheriger Gesprächsverlauf siehe Transkript.',
    coalesce(o.handover_qualified, true),
    'queue:carla-de-overflow'
from public.outcomes o
where o.handover;

-- Integration health: mostly success, ~0.5% failure
insert into public.integration_health (integration, endpoint, status_code, latency_ms, success, conversation_id, created_at)
select
    (array['crm','booking','elevenlabs','n8n'])[1 + (gs % 4)],
    '/webhook/' || (array['get-customer-by-phone','get-appointment','check-availability','reschedule-appointment'])[1 + (gs % 4)],
    case when gs % 200 = 0 then 500 else 200 end,
    80 + (gs % 400),
    (gs % 200 != 0),
    null,
    now() - (gs || ' minutes')::interval
from generate_series(1, 600) as gs;

-- Safety events: a few mock acknowledgement examples
insert into public.safety_events (conversation_id, event_type, detector, severity, action_taken, details, created_at)
select
    o.conversation_id,
    (array['out_of_scope','tool_failure','hallucination_suspect'])[1 + (extract(epoch from o.recomputed_at)::bigint % 3)],
    'rule',
    'warning',
    'warned',
    jsonb_build_object('note','Mock-Ereignis aus Seed-Daten'),
    o.recomputed_at
from public.outcomes o
order by random()
limit 8;

commit;

