# ElevenLabs Outbound Webhook Events — configuration

The agent emits webhooks during and after each conversation. We capture them in n8n and write them to Supabase. **Without these webhooks the dashboard stays empty** — the agent's tool calls alone don't produce a transcript or outcome.

> ElevenLabs' exact event names and payload shapes evolve. Where the platform names differ from those below, set the n8n route to the listed path and the Code node maps the incoming payload to the n8n input shape used by these workflows. The fields the n8n workflows expect are listed for each event.

---

## Common to every webhook

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |
| `X-Auth-Secret` | `{{N8N_SHARED_SECRET}}` |

Optionally enable ElevenLabs' built-in webhook signing (HMAC of the body with a signing secret). If you do, paste the signing secret into n8n as `N8N_ELEVENLABS_SIGNING_SECRET` and uncomment the verification step inside `post_call_finalize`'s first node.

Idempotency key: include ElevenLabs' event id as the body field `event_id`. The n8n workflows use `on_conflict` upserts so retries are safe.

---

## 1. `conversation.started`

| | |
|---|---|
| Trigger | When a call starts |
| URL | `{{N8N_BASE_URL}}/webhook/post-call-finalize` |
| n8n workflow | `post_call_finalize` (start branch) |
| Effect in DB | Inserts `calls` row (by `external_call_id`) and a `conversations` row (`status='in_progress'`), linking to the active `agent_versions.id` |

Body (n8n expects):
```json
{
  "event": "conversation.started",
  "external_call_id": "<elevenlabs conversation id>",
  "started_at": "2026-04-26T10:00:00+02:00",
  "language": "de",
  "consent_recorded": false
}
```

---

## 2. `conversation.turn` (user)

| | |
|---|---|
| Trigger | After each user utterance is finalized by ASR |
| URL | `{{N8N_BASE_URL}}/webhook/log-conversation-turn` |
| n8n workflow | `log_conversation_turn` |
| Effect in DB | Insert into `conversation_turns` |

Body:
```json
{
  "event": "conversation.turn",
  "external_call_id": "<id>",
  "conversation_id": "<our conversation_id, if known; else omit and let n8n resolve from external_call_id>",
  "turn_index": 5,
  "role": "user",
  "text": "Ist mein Auto fertig?",
  "audio_url": null,
  "latency_ms": null,
  "detected_intent": null,
  "intent_confidence": null
}
```

---

## 3. `conversation.turn` (agent)

| | |
|---|---|
| Trigger | After each agent reply is spoken |
| URL | `{{N8N_BASE_URL}}/webhook/log-conversation-turn` |
| n8n workflow | `log_conversation_turn` |
| Effect in DB | Insert into `conversation_turns` (role=`agent`) |

Body:
```json
{
  "event": "conversation.turn",
  "external_call_id": "<id>",
  "turn_index": 6,
  "role": "agent",
  "text": "Ich habe Ihren Termin gefunden. Ihr Fahrzeug ist abholbereit, Filiale Berlin Mitte.",
  "audio_url": "https://...",
  "latency_ms": 820
}
```

---

## 4. `conversation.tool_called`

| | |
|---|---|
| Trigger | When the agent invokes a tool |
| URL | `{{N8N_BASE_URL}}/webhook/log-tool-call` |
| n8n workflow | `log_tool_call` |
| Effect in DB | Insert into `tool_calls` (status preliminarily `success`) |

Body:
```json
{
  "event": "tool_called",
  "external_call_id": "<id>",
  "conversation_id": "<our conversation_id>",
  "tool_call_id": "<elevenlabs tool call id>",
  "tool_name": "get_customer_by_phone",
  "request_payload": { "spoken_phone": "+491701234001", "conversation_id": "..." }
}
```

---

## 5. `conversation.tool_result`

| | |
|---|---|
| Trigger | When the tool returns (or errors out) |
| URL | `{{N8N_BASE_URL}}/webhook/log-tool-call` |
| n8n workflow | `log_tool_call` |
| Effect in DB | PATCH `tool_calls` by id; INSERT into `integration_health` |

Body:
```json
{
  "event": "tool_result",
  "external_call_id": "<id>",
  "conversation_id": "<our conversation_id>",
  "tool_call_id": "<elevenlabs tool call id>",
  "tool_name": "get_customer_by_phone",
  "response_payload": { "ok": true, "data": { "found": true, ... } },
  "status": "success",
  "latency_ms": 480,
  "error_message": null
}
```

---

## 6. `conversation.ended`

| | |
|---|---|
| Trigger | When the call ends (caller hangs up, agent calls `end_call`, or hard timeout) |
| URL | `{{N8N_BASE_URL}}/webhook/post-call-finalize` |
| n8n workflow | `post_call_finalize` (end branch) |
| Effect in DB | PATCH `conversations` (`status`, `ended_at`, `goal_achieved`, `final_intent`); PATCH `calls` (`ended_at`, `duration_seconds`); UPSERT `outcomes` row; ensure `customer_feedback` placeholder exists |

Body:
```json
{
  "event": "conversation.ended",
  "external_call_id": "<id>",
  "ended_at": "2026-04-26T10:04:35+02:00",
  "status": "completed_automated",
  "primary_use_case": 2,
  "final_intent": "appointment_status",
  "goal_achieved": true,
  "abandonment_stage": null,
  "time_to_first_response_ms": 950
}
```

---

## 7. `conversation.transcript_ready`

| | |
|---|---|
| Trigger | When the final transcript / recording URL is available (may arrive seconds after `ended`) |
| URL | `{{N8N_BASE_URL}}/webhook/post-call-finalize` |
| n8n workflow | `post_call_finalize` (transcript branch) |
| Effect in DB | PATCH `calls.recording_url` |

Body:
```json
{
  "event": "conversation.transcript_ready",
  "external_call_id": "<id>",
  "recording_url": "https://elevenlabs-storage.../audio.mp3"
}
```

---

## 8. `conversation.error`

| | |
|---|---|
| Trigger | When the agent runtime errors (TTS failure, model error, unhandled exception) |
| URL | `{{N8N_BASE_URL}}/webhook/log-safety-event` |
| n8n workflow | `log_safety_event` (created as a wrapper or extend `post_call_finalize`) |
| Effect in DB | Insert into `safety_events` with `event_type='tool_failure'`, `severity='error'` |

Body:
```json
{
  "event": "conversation.error",
  "external_call_id": "<id>",
  "conversation_id": "<our conversation_id>",
  "error_type": "tts_timeout",
  "details": "..."
}
```

---

## Verification checklist

After enabling all 8 events, place one test call from the ElevenLabs test console and check:

1. **`calls`** has a new row (`external_call_id` matches the test call's id).
2. **`conversations`** has a new row with `status='in_progress'`.
3. **`conversation_turns`** is growing in real time as you speak (you can watch this via the `/calls/[id]` dashboard page once Phase D is up).
4. When you trigger a tool: **`tool_calls`** row appears, then gets patched with `status` and `latency_ms`.
5. When the call ends: **`conversations.status`** flips to `completed_automated` (or another final status), **`outcomes`** has a new row, **`customer_feedback`** has a row (either with the rating or as a placeholder).
6. **`integration_health`** rows are accumulating; `success` should be ~100% in healthy runs.
