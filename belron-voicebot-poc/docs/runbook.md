# Runbook — end-to-end deployment

A linear setup guide for getting the POC live from a fresh repo.

> Estimated total time: 2–3 hours, the first time.

---

## 1. Prerequisites

- Supabase project (created in the dashboard at https://supabase.com).
- ElevenLabs account on a tier supporting Conversational AI + Knowledge Base + outbound webhooks.
- A reachable n8n instance (cloud or self-hosted).
- Node.js 20+ and npm/pnpm on your laptop.
- A 64-char random hex string. Generate one with: `openssl rand -hex 32`.

## 2. Database

```bash
# from repo root
cd supabase

# Option A: with Supabase CLI (recommended)
supabase db push --db-url "postgres://postgres:PASSWORD@db.YOUR.supabase.co:5432/postgres"

# Option B: run migrations + seed manually via SQL editor in the Supabase UI
# Apply files in this order:
#   migrations/0001_reference.sql
#   migrations/0002_operational.sql
#   migrations/0003_telemetry.sql
#   migrations/0004_governance.sql
#   migrations/0005_agent_ops.sql
#   migrations/0006_indexes_and_rls.sql
#   migrations/0007_kpi_views.sql
# Then run seed.sql.
```

Verify:

```sql
select count(*) from branches;            -- 20
select count(*) from customers;           -- 50
select count(*) from appointments;        -- 150
select count(*) from agent_versions;      -- 3
select count(*) from kpi_overview;        -- 1
```

## 3. n8n

Follow [docs/n8n_setup.md](n8n_setup.md). At the end you should have 12 active workflows; smoke-test them with `curl` (commands in that doc).

## 4. ElevenLabs

Follow [docs/elevenlabs_setup.md](elevenlabs_setup.md). At the end the agent is created, all 11 tools attached, KB uploaded, 8 webhooks configured.

## 5. Dashboard

```bash
cd dashboard
cp .env.example .env.local
# edit .env.local: NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
npm install
npm run dev
# open http://localhost:3000
```

You should see:
- Overview with seeded KPI cards.
- Calls list with the synthetic conversations.
- Per-call transcript pages with CES outcome panel.
- KPIs page with charts populated.

## 6. End-to-end test

1. In ElevenLabs test console, run **Dialogue 2.1** from `elevenlabs/test_dialogues/uc2_status_dialogues.md`.
2. Open dashboard `/calls` in another tab — the live call should appear with status `in_progress`.
3. As you speak, watch `conversation_turns` populate in real time on `/calls/[id]`.
4. End the call (give CES = 8). Confirm:
   - `/calls/[id]` shows the **CES badge** (`8 / 10`) on the right side.
   - `outcomes` row exists, `automated=true`, `aht_seconds` populated.
   - `customer_feedback` row with `ces_score=8`, `ces_collected=true`.
5. Repeat for one dialogue per UC. The Overview page's automation cards should update.

## 7. Going further

- Tighten the system prompt based on real test calls.
- Tune KB retrieval threshold (`similarity_threshold`) if the agent retrieves too aggressively or too conservatively.
- Add real CRM integration: replace the Supabase node in `get_customer_by_phone`, `get_appointment`, etc. with HTTP calls to the real CRM, keeping the same response envelope.
- Wire telephony: change the `transfer_to_agent` workflow to actually bridge the call (via your telephony provider) instead of only writing the handover row.
- Add agent-quality feedback flow: human agents in the queue rate handovers via the dashboard's `/handovers` page; this populates `agent_quality_feedback` and feeds the `kpi_handover_quality` view.

## 8. Common operational questions

**„Wie sehe ich, ob ein Anruf gerade läuft?"**
Dashboard → `/calls` → das grüne „Live-Anrufe"-Badge oben rechts zeigt die aktuelle Anzahl; die Tabelle zeigt `status=in_progress`-Einträge oben.

**„Wie ändere ich den Prompt?"**
Im ElevenLabs UI direkt am Agent — und die neue Version anschließend in Supabase `agent_versions` als neue Zeile mit `is_active=true` speichern (alte Zeile auf `false` setzen).

**„Wie deaktiviere ich Aufzeichnung für einen Anruf?"**
Der Agent fragt zu Beginn nach Einwilligung. Wenn der Anrufer „Nein" sagt, wird `consent_recorded=false` in `calls` gesetzt — und ElevenLabs sollte (per Konfiguration) keine Audio-Aufnahme speichern.

**„Was tun, wenn ein KPI fehlerhaft aussieht?"**
Die KPI-Views sind regulär (nicht materialisiert) — wenn die Daten in den Quelltabellen stimmen, stimmen die KPIs. Wenn nicht: in `outcomes` und `customer_feedback` prüfen, ob `post_call_finalize` den richtigen Datensatz schreibt.
