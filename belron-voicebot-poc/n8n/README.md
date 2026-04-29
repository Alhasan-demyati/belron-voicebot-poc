# n8n Workflows — Carglass Germany Voicebot POC

These workflow JSON files are imported one-by-one into your n8n instance. Each is a webhook that ElevenLabs calls during a conversation; each writes to or reads from Supabase via the PostgREST API.

## Required environment variables

Set these in n8n → **Settings → Variables** (or as host-level env if self-hosting):

| Variable | Example | Used for |
|---|---|---|
| `SUPABASE_URL` | `https://xxxxx.supabase.co` | Base URL for PostgREST calls |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOi...` | Bypasses RLS so n8n can write telemetry |
| `N8N_SHARED_SECRET` | a random 64-char hex string | Must match the `X-Auth-Secret` header sent by ElevenLabs |
| `DEFAULT_COUNTRY_CODE` | `+49` | Used by `get_customer_by_phone` to normalize spoken numbers |

## Import order

Import in any order — there are no inter-workflow dependencies. After import, **activate** each workflow so its webhook URL is live.

1. `get_customer_by_phone.json`
2. `find_customer.json`
3. `get_appointment.json`
4. `list_appointments.json`
5. `check_availability.json`
6. `reschedule_appointment.json`
7. `cancel_appointment.json`
8. `submit_ces_rating.json`
9. `log_conversation_turn.json`
10. `log_tool_call.json`
11. `transfer_to_agent.json`
12. `post_call_finalize.json`

## Webhook URL pattern

Each workflow's path is hard-coded so the URL is predictable:

```
{{ N8N_BASE_URL }}/webhook/<workflow-name-kebab>
```

For example:
- `{{N8N_BASE_URL}}/webhook/get-customer-by-phone`
- `{{N8N_BASE_URL}}/webhook/submit-ces-rating`

These are exactly the URLs you paste into the ElevenLabs tool-builder webhook field.

## Authentication

Every workflow's first node validates an `X-Auth-Secret` header against `{{ $env.N8N_SHARED_SECRET }}`. If absent or wrong → returns 401 immediately. Use the same secret in the ElevenLabs tool config.

## Common response envelope

All read tools return:
```json
{ "ok": true,  "data": { ... } }
```
or on error:
```json
{ "ok": false, "error_code": "NOT_FOUND", "message_for_agent": "Bitte versuchen Sie es erneut." }
```

Write tools (reschedule, cancel, submit_ces_rating, transfer_to_agent) follow the same envelope.

## Logging side effect

Every workflow inserts a row into `integration_health` (success or failure) so the >99% reliability KPI stays accurate. The telemetry workflows (`log_conversation_turn`, `log_tool_call`, `post_call_finalize`) skip this self-log to avoid recursion.
