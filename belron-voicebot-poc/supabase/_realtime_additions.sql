-- Add the remaining tables to the supabase_realtime publication so the
-- dashboard's Realtime subscriptions fire on every relevant change.
-- The base set (conversations, conversation_turns, tool_calls, outcomes,
-- safety_events) was added by migration 0006. Run this once to add the rest.

do $$
declare
  t text;
begin
  foreach t in array array[
    'calls',
    'customer_feedback',
    'handovers',
    'agent_quality_feedback',
    'integration_health',
    'appointment_history',
    'consent_events'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception
      when duplicate_object then
        null;  -- already in publication, ignore
    end;
  end loop;
end$$;

-- Verify: list every table now in the publication
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by tablename;
