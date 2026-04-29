# Agent Settings — recommended values for the ElevenLabs UI

These are the values to set in the **Conversational AI → Agent → Settings** panel for the Carla DE PoC agent.

## Identity

| Field | Value |
|---|---|
| Agent name | `Carla DE PoC v0.3` |
| Description | `Sprachassistentin von Carglass Deutschland — POC build, 4 Use Cases.` |
| Primary language | `German (de)` |
| Fallback language | `English (en)` — only if caller speaks English first |
| Timezone | `Europe/Berlin` |

## LLM

| Field | Value | Why |
|---|---|---|
| Model | The newest reasoning-capable LLM available in your ElevenLabs Conversational AI tier (e.g. GPT-4o, Claude Sonnet, etc.) | UC3/UC4 require multi-step planning and intent switching |
| Temperature | `0.30` | Predictable, fact-grounded answers; low risk of hallucination |
| Top-p | `0.90` | Default; mild diversity in phrasing without veering off |
| Max tokens per response | `400` | Forces concise answers (the prompt already trains brevity) |

## Voice (TTS)

| Field | Value | Why |
|---|---|---|
| Voice | A native German female voice from ElevenLabs' multilingual v2 catalogue. **Recommended starting candidates** (audition all and pick whichever sounds calmest and most natural in your account): `Sarah (multilingual v2 DE)`, `Charlotte (multilingual v2 DE)`, or any voice marked "German native". **Final choice belongs to you** — record the chosen `voice_id` into Supabase `agent_versions.voice_id` so the dashboard can compare versions. |
| Stability | `0.50` | Natural cadence; lower = more expressive, higher = flatter |
| Similarity boost | `0.75` | Keeps voice consistent across long calls |
| Style exaggeration | `0.00` | Avoid theatrical delivery |
| Speaker boost | `true` | Slightly clearer over phone audio |
| Output format | `μ-law 8 kHz` for telephony / SIP, or `PCM 16 kHz` for in-browser test console | Matches downstream audio path |

## ASR (Speech-to-Text)

| Field | Value |
|---|---|
| Language | `de-DE` |
| Model | ElevenLabs default (multilingual ASR) |
| Punctuation | enabled |
| Profanity filter | disabled (we want raw input for safety detection) |

## Turn-taking & timing

| Field | Value | Why |
|---|---|---|
| End-of-speech threshold (silence after caller stops) | `700 ms` | German callers often pause mid-sentence; a 400 ms cutoff feels rude |
| Allow user interruptions (barge-in) | `true` | UC4 multi-intent requires fluid switching |
| Agent yields on barge-in | immediately | Don't talk over the caller |
| Initial silence timeout (after greeting, before reprompt) | `8 s` | "Sind Sie noch da?" |
| Subsequent silence timeout (during conversation) | `25 s` | Offer handover or wrap up gracefully |
| Hard hang-up timeout (after no response) | `40 s` | Auto-end with `outcome=abandoned` |
| Max conversation duration | `8 min` | UX + cost guardrail; over this → `transfer_to_agent(reason_code='out_of_scope')` |

## First message (greeting)

Mode: **Greet first, with a fixed greeting**. Paste this into the "Initial message" field:

```
Guten Tag, hier ist Carla von Carglass Deutschland. Dürfen wir das Gespräch zu Schulungs- und Qualitätszwecken aufzeichnen?
```

(The system prompt covers the consent fork — "Yes" / "No" / "What does that mean?".)

## Tools

Attach **all 12 tools** from `elevenlabs/tool_schemas.json`. See `elevenlabs/tool_webhook_configs.md` for paste-ready per-tool blocks.

Set the tool execution mode to **synchronous** for read tools (`get_customer_by_phone`, `find_customer`, `get_appointment`, `list_appointments`, `check_availability`) and write tools (`book_appointment`, `reschedule_appointment`, `cancel_appointment`, `submit_ces_rating`, `transfer_to_agent`). The agent should wait for the response before continuing.

`end_call` and `log_safety_event` can be **fire-and-forget** if your ElevenLabs version supports it — they don't block the conversation.

## Knowledge Base

Attach the KB built from `elevenlabs/kb/` (30 German articles).

| Field | Value |
|---|---|
| Retrieval mode | semantic |
| Chunk size | `512` tokens |
| Chunk overlap | `64` tokens |
| Top-K retrieved | `3` |
| Similarity threshold | `0.30` (lower = more permissive; tune after smoke tests) |
| Re-rank | enabled if available |

## Webhooks (outbound)

Configure the 8 events listed in `elevenlabs/webhook_events.md`. Use the same `X-Auth-Secret` header as for tools.

## Guardrails

| Field | Value |
|---|---|
| Forbidden topics | legal advice, medical advice, anything outside Carglass / auto-glass scope, political topics, romantic content |
| PII redaction in logs | enable masking of full credit-card / IBAN if exposed by ASR |
| Output safety filter | enabled (default) |
| Max consecutive tool calls | `5` (then `transfer_to_agent`) |

## Recording

| Field | Value |
|---|---|
| Audio recording | **gated by caller consent** — record only if caller said yes to the consent question |
| Transcript storage | always (transcripts are not audio; PII redaction applies on display) |
| Recording retention | 90 days (POC default; align with your data-protection policy before going live) |

## Save as version

After saving, copy the agent's system prompt + tool schema + voice ID into Supabase `agent_versions` (use the dashboard's `/agent-versions` page once the dashboard is up). Set `is_active = true`. The dashboard's version-comparison page reads from this table.
