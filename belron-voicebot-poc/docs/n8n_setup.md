# n8n Setup — click-by-click runbook

Deploy and configure the 12 n8n workflows that connect ElevenLabs to Supabase.

> Estimated time: 30 minutes once your n8n instance is running.

---

## 0. Prerequisites

- A running n8n instance, **publicly reachable** (ElevenLabs needs to call its webhooks). Cloud or self-hosted both work.
- Supabase project with migrations + seed applied.
- Service role key from Supabase (Settings → API → `service_role`).
- A 64-char random hex string to use as the **shared secret** between ElevenLabs and n8n.

## 1. Set environment variables

In n8n: **Settings → Variables** (or, if self-hosted, set them as host env vars and restart):

| Name | Value |
|---|---|
| `SUPABASE_URL` | `https://xxxxx.supabase.co` (no trailing slash) |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOiJI...` |
| `N8N_SHARED_SECRET` | your random 64-char hex |
| `DEFAULT_COUNTRY_CODE` | `+49` |

Save.

## 2. Import the workflows

For each file in `belron-voicebot-poc/n8n/workflows/`:

1. n8n top-right → **Import from file**.
2. Select the JSON file.
3. n8n shows the workflow editor with all nodes laid out. Don't change anything.
4. Click **Save**.
5. Toggle **Active** in the top-right.

Order doesn't matter; the 12 workflows are independent. After all 12 are active, the URL list looks like:

- `{{N8N_BASE_URL}}/webhook/get-customer-by-phone`
- `{{N8N_BASE_URL}}/webhook/find-customer`
- `{{N8N_BASE_URL}}/webhook/get-appointment`
- `{{N8N_BASE_URL}}/webhook/list-appointments`
- `{{N8N_BASE_URL}}/webhook/check-availability`
- `{{N8N_BASE_URL}}/webhook/reschedule-appointment`
- `{{N8N_BASE_URL}}/webhook/cancel-appointment`
- `{{N8N_BASE_URL}}/webhook/submit-ces-rating`
- `{{N8N_BASE_URL}}/webhook/log-conversation-turn`
- `{{N8N_BASE_URL}}/webhook/log-tool-call`
- `{{N8N_BASE_URL}}/webhook/transfer-to-agent`
- `{{N8N_BASE_URL}}/webhook/post-call-finalize`

## 3. Smoke test each webhook

Use `curl` from your laptop. Replace `BASE` and `SECRET` with your real values.

```bash
BASE="https://n8n.your-host.tld"
SECRET="your-shared-secret"

# 1) Auth check (must return 200; missing header returns 401)
curl -X POST "$BASE/webhook/get-customer-by-phone" \
  -H "Content-Type: application/json" \
  -H "X-Auth-Secret: $SECRET" \
  -d '{"spoken_phone": "0170 1234 001", "conversation_id": null}'
# Expected: { "ok": true, "data": { "found": true, "customer": {...} } }
#           (with the seeded Lukas Müller record)

# 2) Auth fails without secret
curl -X POST "$BASE/webhook/get-customer-by-phone" \
  -H "Content-Type: application/json" \
  -d '{"spoken_phone": "0170 1234 001"}'
# Expected: 401, { "ok": false, "error_code": "UNAUTHORIZED" }

# 3) Confirmation_token enforcement on writes
curl -X POST "$BASE/webhook/reschedule-appointment" \
  -H "Content-Type: application/json" \
  -H "X-Auth-Secret: $SECRET" \
  -d '{"appointment_id": "non-existent", "new_start": "2026-05-01T10:00:00+02:00"}'
# Expected: { "ok": false, "error_code": "CONFIRMATION_REQUIRED", ... }

# 4) submit_ces_rating
curl -X POST "$BASE/webhook/submit-ces-rating" \
  -H "Content-Type: application/json" \
  -H "X-Auth-Secret: $SECRET" \
  -d '{"conversation_id": "00000000-0000-0000-0000-000000000000", "score": 8}'
# Expected: ok=false (conversation doesn't exist) or ok=true (depends on whether you point at a real conversation)
```

## 4. Watch executions

n8n → tab **Executions** (left nav). Every webhook hit shows up as a new execution. Click into any to see node-by-node input/output and timings. This is your single best debugging surface.

If a node turns red:
- HTTP Request to Supabase failed → check `SUPABASE_URL` and key.
- Code node threw → click into it; n8n shows the JS error and the input data.

## 5. Performance & limits

For the POC, default n8n settings are fine. As the call volume grows:

- Set **Execution timeout** per workflow (Workflow → Settings) to ~15 s — long-running executions block resources.
- Enable **Save successful executions: false** if you don't need every successful execution stored (`integration_health` already captures success rates).
- Keep the **executions data retention** at 7 days for debugging.

## 6. Updating workflows

When you change a workflow JSON in this repo:

1. n8n → workflow → top-right kebab → **Replace from file** (or delete + re-import).
2. Re-activate.

If you only changed business logic in a Code node, you can edit the node directly in n8n and **export** the updated JSON back into the repo to keep them in sync.

## 7. Optional: webhook authenticity verification

The current setup uses a static shared secret (`X-Auth-Secret` header). If you also want HMAC body signing from ElevenLabs:

1. Generate a signing secret in ElevenLabs → Webhooks → Signing.
2. Set it in n8n as `N8N_ELEVENLABS_SIGNING_SECRET`.
3. Add a Code node before the existing Auth Check node in `post_call_finalize` (and any other entry-point workflow) that verifies HMAC-SHA256(`body`, `N8N_ELEVENLABS_SIGNING_SECRET`) against the `X-ElevenLabs-Signature` header. Reject mismatches with 401.

Optional for POC; recommended before going live.
