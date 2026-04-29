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
