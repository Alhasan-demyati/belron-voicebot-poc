# Tool Webhook Configs — paste-ready blocks

For each of the 11 tools, configure the webhook in the ElevenLabs Tool Builder using the block below. All tools share these placeholder values:

- `{{N8N_BASE_URL}}` — your n8n public base URL (e.g. `https://n8n.your-host.tld`)
- `{{N8N_SHARED_SECRET}}` — the same secret you set in n8n's `N8N_SHARED_SECRET` env var
- `{{system__conversation_id}}` — ElevenLabs system variable, automatically substituted at call time

Common error-response shape (every tool returns this on failure — already handled by the prompt's tool-error rules):
```json
{ "ok": false, "error_code": "...", "message_for_agent": "Bitte versuchen Sie es erneut." }
```

---

## 1. `get_customer_by_phone`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/get-customer-by-phone
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "spoken_phone":    "{{phone}}"
  }
Expected 200 response:
  {
    "ok": true,
    "data": {
      "found": true|false,
      "customer": { "id", "first_name", "last_name", "phone_e164", "language" } | null,
      "recent_appointments": [{
        "booking_reference", "status", "scheduled_start", "branch_name"
      }]
    }
  }
Timeout: 8000 ms
```

---

## 2. `find_customer`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/find-customer
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "license_plate":   "{{license_plate}}",
    "booking_ref":     "{{booking_ref}}",
    "name":            "{{name}}",
    "postal_code":     "{{postal_code}}"
  }
Expected 200 response:
  { "ok": true, "data": { "found": ..., "customer": ..., "recent_appointments": [...] } }
Timeout: 8000 ms
```

---

## 3. `get_appointment`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/get-appointment
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "appointment_id":  "{{appointment_id}}",
    "booking_ref":     "{{booking_ref}}"
  }
Expected 200 response:
  {
    "ok": true,
    "data": {
      "found": true|false,
      "appointment": {
        "id", "booking_reference", "status",
        "scheduled_start", "scheduled_end", "eta_ready_at",
        "branch_name", "branch_city", "branch_phone", "service_name"
      } | null
    }
  }
Timeout: 8000 ms
```

---

## 4. `list_appointments`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/list-appointments
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "customer_id":     "{{customer_id}}"
  }
Expected 200 response:
  {
    "ok": true,
    "data": {
      "count": <int>,
      "appointments": [{
        "id", "booking_reference", "status",
        "scheduled_start", "scheduled_end",
        "branch_id", "branch_name", "branch_city",
        "service_id", "service_name"
      }]
    }
  }
Timeout: 8000 ms
```

---

## 5. `check_availability`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/check-availability
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "branch_id":  "{{branch_id}}",
    "service_id": "{{service_id}}",
    "from_date":  "{{from_date}}",
    "to_date":    "{{to_date}}"
  }
Expected 200 response:
  {
    "ok": true,
    "data": {
      "branch_id", "service_id", "duration_minutes",
      "slots": [{ "start": "ISO-8601", "end": "ISO-8601" }, ...up to 12]
    }
  }
Timeout: 10000 ms
```

---

## 6. `reschedule_appointment`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/reschedule-appointment
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id":    "{{system__conversation_id}}",
    "appointment_id":     "{{appointment_id}}",
    "new_start":          "{{new_start}}",
    "confirmation_token": "{{confirmation_token}}"
  }
Hard rule: if confirmation_token is empty/missing, n8n returns:
  { "ok": false, "error_code": "CONFIRMATION_REQUIRED",
    "message_for_agent": "Bitte zuerst die neue Uhrzeit mit dem Kunden bestätigen." }
Expected 200 response:
  {
    "ok": true,
    "data": {
      "appointment": { "id", "booking_reference", "new_start", "new_end", "status" }
    }
  }
Timeout: 10000 ms
```

---

## 7. `cancel_appointment`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/cancel-appointment
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id":    "{{system__conversation_id}}",
    "appointment_id":     "{{appointment_id}}",
    "reason":             "{{reason}}",
    "confirmation_token": "{{confirmation_token}}"
  }
Expected 200 response:
  { "ok": true, "data": { "cancelled": true, "appointment_id": "..." } }
Timeout: 10000 ms
```

---

## 8. `transfer_to_agent`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/transfer-to-agent
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "reason_code":     "{{reason_code}}",
    "summary":         "{{summary}}",
    "customer_data":   "{{customer_data}}"
  }
Expected 200 response:
  {
    "ok": true,
    "data": {
      "handover_created": true,
      "qualified": true|false,
      "queue": "queue:carla-de-overflow"
    }
  }
Timeout: 8000 ms
Note: at POC start, this only writes the handover row in Supabase.
      Real telephony bridging is wired later.
```

---

## 9. `submit_ces_rating`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/submit-ces-rating
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "score":           "{{score}}",
    "declined":        "{{declined}}",
    "comment":         "{{comment}}"
  }
Expected 200 response:
  { "ok": true, "data": { "saved": true, "ces_score": 1..10|null, "ces_collected": true|false } }
Timeout: 6000 ms
```

---

## 10. `log_safety_event`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/log-safety-event
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "conversation_id": "{{system__conversation_id}}",
    "event_type":      "{{event_type}}",
    "severity":        "{{severity}}",
    "details":         "{{details}}"
  }
Expected 200 response:
  { "ok": true }
Timeout: 6000 ms

Note: this tool does not have a dedicated workflow file in n8n/workflows/
yet — it can be implemented either as a thin wrapper that POSTs to the
Supabase REST endpoint /rest/v1/safety_events directly, or by extending
post_call_finalize with an additional event handler. For the POC, the
simplest pattern is a one-node n8n workflow modeled on submit_ces_rating.
```

---

## 11. `end_call`

```
Method:  POST
URL:     {{N8N_BASE_URL}}/webhook/post-call-finalize
Headers:
  Content-Type:   application/json
  X-Auth-Secret:  {{N8N_SHARED_SECRET}}
  X-Source:       elevenlabs
Request body:
  {
    "event":            "conversation.ended",
    "external_call_id": "{{system__conversation_id}}",
    "ended_at":         "{{system__now}}",
    "status":           "{{outcome}}"
  }
Expected 200 response:
  { "ok": true, "data": { "conversation_id": "...", "status": "...", "aht_seconds": <int>, "tool_calls_count": <int> } }
Timeout: 8000 ms
```

---

## Test ping pattern

After configuring each tool, the ElevenLabs Tool Builder offers a "Test" button. Use it with these probe payloads:

| Tool | Test parameter values |
|---|---|
| `get_customer_by_phone` | `phone: "0170 1234 999"` (won't match — expects `found: false`) |
| `find_customer`        | `booking_ref: "CG-NOPE-X"` (won't match) |
| `get_appointment`      | `booking_ref: "CG-NOPE-X"` |
| `list_appointments`    | `customer_id: "00000000-0000-0000-0000-000000000000"` |
| `check_availability`   | use a real branch + service id from `seed.sql`, dates a few days out |
| `reschedule_appointment` | leave `confirmation_token` empty → expect `CONFIRMATION_REQUIRED` |
| `cancel_appointment`   | leave `confirmation_token` empty → expect `CONFIRMATION_REQUIRED` |
| `submit_ces_rating`    | `score: 8, declined: false` |
| `transfer_to_agent`    | `reason_code: "customer_request", summary: "Test ping from ElevenLabs tool builder."` |
| `end_call`             | `outcome: "completed_automated"` |

A 401 response means the `X-Auth-Secret` header doesn't match `N8N_SHARED_SECRET` in n8n.
