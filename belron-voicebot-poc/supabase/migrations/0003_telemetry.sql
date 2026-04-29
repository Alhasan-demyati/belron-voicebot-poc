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
