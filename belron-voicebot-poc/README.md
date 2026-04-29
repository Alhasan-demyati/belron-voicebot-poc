# Carglass Germany Voicebot POC

End-to-end build for the Carglass Germany **Remona** voicebot Proof-of-Concept. Validates whether an LLM/agentic voicebot can outperform the current deterministic Carla on automation rate, abandonment, configuration velocity, and customer effort, across **4 use cases**:

1. **UC1 — Q&A** (target automation **70%**)
2. **UC2 — Appointment Status Check** (target **80%**)
3. **UC3 — Appointment Rescheduling** (target **40%**)
4. **UC4 — Ambiguous / Multi-Intent** (no fixed target; goal: completion of final intent)

## Architecture

```
Caller (DE)  →  ElevenLabs Conversational AI Agent ("Remona")  →  n8n webhooks  →  Supabase (Postgres + Realtime + Auth)
                                                                                            ↓
                                                                                Next.js Dashboard
                                                                                (live calls, KPIs, transcripts)
```

- **ElevenLabs** runs the voice agent. The German system prompt and 11 tool definitions live in [elevenlabs/](elevenlabs/).
- **ElevenLabs Knowledge Base** holds 30 German FAQ articles ([elevenlabs/kb/](elevenlabs/kb/)) for UC1/UC4.
- **n8n** hosts 12 webhook workflows ([n8n/workflows/](n8n/workflows/)) that ElevenLabs calls during conversations.
- **Supabase** is the system of record for branches, customers, appointments, and all telemetry (calls, conversations, turns, tool calls, outcomes, CES feedback).
- **Next.js dashboard** ([dashboard/](dashboard/)) renders live call monitoring + KPI scorecard + transcript viewer with CES.

## Repo layout

| Folder | What's in it |
|---|---|
| [supabase/](supabase/) | 7 SQL migrations + German mock seed data |
| [n8n/workflows/](n8n/workflows/) | 12 importable JSON workflow templates |
| [elevenlabs/](elevenlabs/) | Full German system prompt, tool schemas, agent settings, 8 webhook event configs, 30 KB articles, 4 test-dialogue files |
| [dashboard/](dashboard/) | Next.js 15 app router dashboard (Supabase + Tailwind + Recharts) |
| [docs/](docs/) | Setup runbooks, KPI definitions, handover contract |

## What you (user) provide

- Supabase project URL + anon key + service role key
- ElevenLabs account on a tier with Conversational AI + KB + outbound webhooks
- n8n instance reachable from the internet
- A 64-char shared secret (used by ElevenLabs ↔ n8n auth header)

## Quick start

1. **Database**: see [docs/runbook.md](docs/runbook.md) for `supabase db push` + seed.
2. **n8n**: see [docs/n8n_setup.md](docs/n8n_setup.md). Import the 12 workflow JSON files, set the four env vars, activate.
3. **ElevenLabs**: see [docs/elevenlabs_setup.md](docs/elevenlabs_setup.md). Create the agent, paste the German prompt, attach all 11 tools, upload the 30 KB articles, configure the 8 outbound webhooks.
4. **Dashboard**: `cd dashboard && cp .env.example .env.local`, fill in Supabase URL + keys, `npm install && npm run dev`.

## Use-case verification

After everything is wired, run the test dialogues from [elevenlabs/test_dialogues/](elevenlabs/test_dialogues/) — there are 13 scripted dialogues covering UC1–UC4 happy paths, edge cases, and regression tests (no-write-before-confirmation, location-change handover, CES capture).

## POC measures the dashboard tracks

- Automation rate per UC vs targets (70/80/40)
- Abandonment rate vs Carla baseline (8.7%)
- Qualified handover rate
- AHT distribution (p50 / p90 / p99)
- Integration reliability (>99% target)
- **CES (1–10)** — average per UC, distribution histogram, weekly trend, capture rate
- Configuration velocity (agent_versions deployed per week)

## Important constraints (POC)

- **No telephony number / caller-ID at start.** The agent always asks the caller to speak their phone number, repeats the digits to confirm, then uses it as the primary identifier.
- **Knowledge Base is in ElevenLabs**, not Supabase. UC1/UC4 grounding comes from the attached KB feature.
- **No SMS.** CES is collected **in-call only** at the end of every call, on a 1–10 scale, via the `submit_ces_rating` tool.
- **No write actions without verbal confirmation.** `reschedule_appointment` / `cancel_appointment` require a `confirmation_token` parameter.
