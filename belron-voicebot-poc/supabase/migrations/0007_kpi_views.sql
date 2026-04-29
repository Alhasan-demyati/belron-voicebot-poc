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
