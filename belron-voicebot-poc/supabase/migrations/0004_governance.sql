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
