# KPI Definitions

Exact formulas for every measure listed in the POC briefing. Each KPI is implemented as a SQL view in `supabase/migrations/0007_kpi_views.sql` and queried by `dashboard/lib/kpis.ts`.

---

## Automation rate per use case

**Definition.** Share of completed conversations of a given UC that ended without human handover.

**Formula.**
```
automation_rate(uc) =
  count(outcomes where use_case = uc and automated = true)
  / count(outcomes where use_case = uc)
```

**View.** `kpi_automation_by_usecase`

**Targets.** UC1: 70%, UC2: 80%, UC3: 40%. UC4 is measured by `customer_goal_completed`, no fixed target.

**Edge cases.**
- `outcomes.use_case IS NULL` rows are excluded (intent not detected).
- `abandoned=true` rows count toward the denominator but not the numerator.

---

## Abandonment rate

**Definition.** Share of conversations that ended without completing or handing over (caller hung up or hard-timed-out without resolution).

**Formula.**
```
abandonment_rate = count(outcomes where abandoned = true) / count(outcomes)
```

**View.** `kpi_abandonment_funnel` provides the breakdown by `abandonment_stage` (one of: `intent_detection`, `identification`, `search`, `confirmation`, `other`).

**Benchmark.** Carla's current abandonment ≈ **8.7%** (per POC briefing). The new bot must not exceed it.

---

## Qualified handover rate

**Definition.** Among all handovers, the share that pass the quality bar (summary present, customer data present).

**Formula.**
```
qualified_handover_rate =
  count(handovers where qualified = true) / count(handovers)
```

`qualified` is set by the `transfer_to_agent` n8n workflow heuristically: summary length ≥ 20 chars AND `customer_data` contains at least a name OR phone.

Optional human review: agents in the queue rate the handover via `agent_quality_feedback.was_qualified` — the `kpi_handover_quality` view averages those scores.

**View.** `kpi_handover_quality`.

---

## AHT (Average Handle Time)

**Definition.** Wall-clock conversation duration, end-to-end.

**Formula.**
```
aht_seconds = ended_at - started_at  (per conversation)
```

We report **p50, p90, p99** per UC, plus a simple mean. View: `kpi_aht_distribution`.

**Why p99 matters.** Outliers reveal stuck flows that an average smooths over.

---

## Integration reliability (>99% target)

**Definition.** Share of integration calls that returned successfully (HTTP 200 + valid response) within the configured timeout.

**Formula.**
```
success_rate(integration, day) =
  count(integration_health where integration = X and day = D and success = true)
  / count(integration_health where integration = X and day = D)
```

`integration` is one of: `crm`, `booking`, `elevenlabs`, `n8n`, `telephony`, `other`.

The `log_tool_call` workflow inserts an `integration_health` row for every tool call (success or failure). The `post_call_finalize` and other entry-point workflows do too.

**View.** `kpi_integration_reliability`.

**Target.** ≥ **99.0%** rolling 7d.

---

## CES (Customer Effort Score, 1–10)

**Definition.** Caller-spoken rating at the end of every call, on a scale 1 (very poor) to 10 (excellent).

**Tool.** `submit_ces_rating(score, declined?, comment?)`.

**Captured in.** `customer_feedback`:
- `ces_score` SMALLINT 1–10
- `ces_collected` BOOLEAN — true when a number was actually obtained, false when caller declined / hung up
- `ces_question` — the exact German prompt the agent used
- `comment_text` — optional caller-provided reason
- `source = 'in_call'`

**Capture rate.**
```
ces_capture_rate = count(customer_feedback where ces_collected = true) / count(customer_feedback)
```

If the caller hangs up before the CES question, `post_call_finalize` inserts a placeholder `customer_feedback` row with `ces_collected=false` so the capture-rate denominator stays accurate.

**Views.**
- `kpi_ces_avg_by_usecase` — average per UC × week
- `kpi_ces_distribution` — histogram across 1..10 per UC
- `kpi_ces_capture_rate` — daily capture rate

---

## Configuration velocity

**Definition.** Number of agent versions deployed per week. Proxy for "time to ship a new intent / change a policy".

**View.** `kpi_velocity_changelog`.

The POC briefing's "Velocity of new intent deployment" measure uses this directly: count releases per week.

---

## Customer goal completed (UC4 measure)

**Definition.** Did the caller's *final* intent (in case they switched mid-call) get fulfilled?

**Field.** `outcomes.customer_goal_completed` BOOLEAN.

**Set by.** `post_call_finalize` based on:
- `automated=true` → goal completed (caller finished their flow without handover).
- `handover=true && goal_achieved=true` (set by ElevenLabs `conversation.ended` payload) → goal completed via human.
- Otherwise null/false.

This is the primary measure for **UC4** since UC4 has no fixed automation target — a caller switching from reschedule → cancel → reschedule and ending happy counts as goal-completed.

---

## How to read the dashboard

- **Overview page** (`/`): high-level KPI cards (automation, abandonment, qualified handover, AHT, reliability, CES, capture rate) plus per-UC progress bars vs targets.
- **KPIs page** (`/kpis`): full charts — automation bars vs targets, CES distribution histogram, weekly CES line chart per UC, AHT/handover/abandonment tables, integration-reliability line chart with the 99% reference line.
- **Calls list** (`/calls`): filter by status, UC, CES bucket. Click into a call for the transcript + CES outcome panel.

All KPIs are computed live from the views; no separate ETL or rollup job is required. To recompute the `outcomes` row for a specific conversation (e.g. after fixing an `agent_quality_feedback` rating), call `post_call_finalize` again with the same `external_call_id` — it's idempotent.
