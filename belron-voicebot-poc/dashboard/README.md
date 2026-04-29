# Dashboard

Next.js 15 app router dashboard for the Carla DE Voicebot POC. Reads from Supabase (REST + Realtime), renders KPIs and live transcripts.

## Setup

```bash
cp .env.example .env.local
# fill in:
#   NEXT_PUBLIC_SUPABASE_URL
#   NEXT_PUBLIC_SUPABASE_ANON_KEY
#   SUPABASE_SERVICE_ROLE_KEY (only for server actions; not used in the POC build yet)
npm install
npm run dev
```

Open http://localhost:3000.

## Pages

| Path | Purpose |
|---|---|
| `/` | POC scorecard — automation per UC vs targets, CES, abandonment, reliability |
| `/calls` | Live + historical conversations, filter by status / UC / CES bucket |
| `/calls/[id]` | Linear transcript with interleaved tool calls + outcome + CES panel |
| `/kpis` | Detailed charts: automation bars, CES distribution + weekly trend, AHT, handover quality, integration reliability |
| `/branches` | Read-only list of seeded branches |
| `/appointments` | Read-only list of seeded appointments |
| `/agent-versions` | Per-version performance (CES delta, automation, AHT) |
| `/handovers` | Qualified handover queue |
| `/safety` | Safety-event stream |
| `/settings` | Connection info |

## Realtime

Live calls list and live transcript subscribe to Supabase Realtime via `@supabase/ssr` browser client. The publication is set up by `supabase/migrations/0006_indexes_and_rls.sql`.

## Stack

- Next.js 15 (app router, RSC by default)
- Tailwind CSS 3
- shadcn-style minimal components (no shadcn install — just inline classes for portability)
- Recharts for charts
- Supabase JS + SSR helpers
