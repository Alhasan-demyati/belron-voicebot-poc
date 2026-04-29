# ElevenLabs Setup — click-by-click runbook

A linear walkthrough for building the **Remona DE PoC** agent in the ElevenLabs Conversational AI UI. Follow it in order; do not skip steps.

> **Estimated time:** 60–90 minutes the first time. After this, version updates take 5–10 minutes.

---

## 0. Prerequisites

Before you start:

- [ ] An ElevenLabs account on a tier that supports **Conversational AI**, **outbound webhooks**, and **Knowledge Base** features.
- [ ] Your **n8n** instance is reachable from the internet (public URL). Note the base URL: `{{N8N_BASE_URL}}`.
- [ ] Your **Supabase** project is created and migrations + seed are applied (see `docs/runbook.md`). You have:
  - Project URL: `{{SUPABASE_URL}}`
  - Service role key: `{{SUPABASE_SERVICE_ROLE_KEY}}`
- [ ] You've **generated a shared secret** (any 64-char random hex). This is `{{N8N_SHARED_SECRET}}`. Set it both in n8n and in every ElevenLabs tool config (header `X-Auth-Secret`).
- [ ] All 12 n8n workflows are imported and **active** (see `docs/n8n_setup.md`).
- [ ] You have this folder on your machine: `belron-voicebot-poc/elevenlabs/`.

---

## 1. Create the agent

1. Sign in to ElevenLabs → top nav → **Conversational AI** → **Agents**.
2. Click **+ Create agent**.
3. Settings:
   - Name: `Remona DE PoC v0.3`
   - Description: `Sprachassistentin von Carglass Deutschland — POC build, 4 Use Cases.`
   - Primary language: `German (de-DE)`
4. Save.

---

## 2. Paste the system prompt

1. Inside the new agent → tab **Persona / Instructions** → field **System Prompt**.
2. Open `belron-voicebot-poc/elevenlabs/system_prompt.md` in a text editor.
3. Copy the **entire** file contents (yes, including the headings — markdown is fine in the prompt field).
4. Paste into the System Prompt field.
5. Save.

> If your ElevenLabs UI renders the prompt as plain text, that's fine — markdown structure is for the LLM, not the UI.

---

## 3. Set voice / model / temperature / turn-taking

Open `elevenlabs/agent_settings.md` for the values. Quick fill:

| Setting | Value |
|---|---|
| LLM model | the latest reasoning model your tier offers |
| Temperature | `0.30` |
| Top-p | `0.90` |
| Max tokens | `400` |
| Voice | a German female voice (audition; see notes in `agent_settings.md`) |
| Stability | `0.50` |
| Similarity boost | `0.75` |
| Style | `0.00` |
| Speaker boost | enabled |
| ASR language | `de-DE` |
| End-of-speech threshold | `700 ms` |
| Allow interruptions / barge-in | enabled |
| Initial silence timeout | `8 s` |
| Subsequent silence timeout | `25 s` |
| Hard hang-up timeout | `40 s` |
| Max conversation duration | `8 min` |
| Output format | `μ-law 8 kHz` (telephony) or `PCM 16 kHz` (web test) |

Save.

---

## 4. Initial message (greeting)

1. Field **Initial message** / **First-message mode**: set to **Greet first** with a fixed greeting.
2. Paste:

   ```
   Guten Tag, hier ist Remona von Carglass Deutschland. Dürfen wir das Gespräch zu Schulungs- und Qualitätszwecken aufzeichnen?
   ```

Save.

---

## 5. Add the 11 tools

For each tool listed in `elevenlabs/tool_webhook_configs.md`, do the following:

1. Tab **Tools** → **+ Add tool** → **Custom (webhook)**.
2. Open `elevenlabs/tool_schemas.json` and copy the relevant tool object (one of the 11).
3. Paste **name**, **description**, and **parameters** into the Tool Builder fields.
4. In the **Webhook** section, paste the URL (e.g. `{{N8N_BASE_URL}}/webhook/get-customer-by-phone`).
5. Method: **POST**.
6. Add headers (each on its own row):
   - `Content-Type: application/json`
   - `X-Auth-Secret: {{N8N_SHARED_SECRET}}`
   - `X-Source: elevenlabs`
7. Request body: copy the `request_body_template` from the JSON. ElevenLabs will substitute parameter placeholders at call time.
8. Set timeout from the JSON.
9. Click **Test** with the probe payload from the **Test ping pattern** section of `tool_webhook_configs.md`. Expect a 200 with the documented response, or a 401 if your `X-Auth-Secret` is wrong.

Repeat for **all 11** tools:
- `get_customer_by_phone`
- `find_customer`
- `get_appointment`
- `list_appointments`
- `check_availability`
- `reschedule_appointment`
- `cancel_appointment`
- `transfer_to_agent`
- `submit_ces_rating`
- `log_safety_event`
- `end_call`

> **Common failures:**
> - `401 Unauthorized` → secret mismatch. Check both n8n env var and ElevenLabs tool header.
> - `404 Not Found` → workflow not active in n8n, or path mismatch (must match `webhookId` in the workflow JSON).
> - `Timeout` → n8n cannot reach Supabase (check `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in n8n env vars).

After all 11 tools are saved, the agent's tool count in the Tools tab should read **11**.

---

## 6. Upload the Knowledge Base

1. Tab **Knowledge Base** → **+ Upload documents**.
2. Drag **all 30 markdown files** from `belron-voicebot-poc/elevenlabs/kb/` into the upload zone (skip `README.md`).
3. Wait for indexing (1–2 minutes; UI shows progress per document).
4. Settings panel:
   - Retrieval mode: **semantic**
   - Chunk size: `512`
   - Chunk overlap: `64`
   - Top-K: `3`
   - Similarity threshold: `0.30`
   - Re-rank: enabled (if available in your tier)
5. Attach the KB to your agent (toggle **Attach to: Remona DE PoC v0.3**).
6. Save.

Quick verification:
- In the agent's test console, ask: „Was ist Kalibrierung?" — agent should answer with content from `06_kalibrierung.md` without calling any tool.
- Ask: „Was tun bei einem Steinschlag?" — should return content from `08_steinschlag_was_tun.md`.

---

## 7. Configure outbound webhooks

Tab **Webhooks** (or **Settings → Outbound events**, depending on your UI version).

For each event listed in `elevenlabs/webhook_events.md`, add a webhook:

| Event | URL | Header `X-Auth-Secret` |
|---|---|---|
| `conversation.started` | `{{N8N_BASE_URL}}/webhook/post-call-finalize` | `{{N8N_SHARED_SECRET}}` |
| `conversation.turn` (user) | `{{N8N_BASE_URL}}/webhook/log-conversation-turn` | `{{N8N_SHARED_SECRET}}` |
| `conversation.turn` (agent) | `{{N8N_BASE_URL}}/webhook/log-conversation-turn` | `{{N8N_SHARED_SECRET}}` |
| `conversation.tool_called` | `{{N8N_BASE_URL}}/webhook/log-tool-call` | `{{N8N_SHARED_SECRET}}` |
| `conversation.tool_result` | `{{N8N_BASE_URL}}/webhook/log-tool-call` | `{{N8N_SHARED_SECRET}}` |
| `conversation.ended` | `{{N8N_BASE_URL}}/webhook/post-call-finalize` | `{{N8N_SHARED_SECRET}}` |
| `conversation.transcript_ready` | `{{N8N_BASE_URL}}/webhook/post-call-finalize` | `{{N8N_SHARED_SECRET}}` |
| `conversation.error` | `{{N8N_BASE_URL}}/webhook/log-safety-event` | `{{N8N_SHARED_SECRET}}` |

Optional: enable webhook signing with an HMAC secret if available — and set the secret in n8n as `N8N_ELEVENLABS_SIGNING_SECRET`.

Save.

---

## 8. Set guardrails

Tab **Guardrails** (or under **Persona → Safety**):

- Forbidden topics: legal advice, medical advice, anything outside Carglass scope, political topics.
- PII redaction: enabled for full credit-card / IBAN.
- Max consecutive tool calls: `5`.
- Output safety filter: enabled (default).

Save.

---

## 9. Smoke test in the test console

1. Tab **Test** (or **Try it / Playground**).
2. Click **Start conversation**.
3. Run **Dialogue 1.1** from `elevenlabs/test_dialogues/uc1_qa_dialogues.md` (the simplest happy path).
4. While the call is in progress, open Supabase:
   - Table `calls` → new row appearing? `external_call_id` matches?
   - Table `conversations` → new row, `status='in_progress'`?
   - Table `conversation_turns` → rows being inserted as you talk?
5. End the call (say goodbye, agent asks CES, give an 8, agent says auf Wiederhören).
6. Check:
   - `tool_calls` → at least 1 entry for `submit_ces_rating`.
   - `outcomes` → row with `automated=true`.
   - `customer_feedback` → row with `ces_score=8`, `ces_collected=true`.
7. **If anything is missing**, see the troubleshooting list below.

---

## 10. Promote to first agent_version row

Once the smoke test passes, open the dashboard's `/agent-versions` page (after Phase D is up) and click **Add version**:

- Version: `0.3.0`
- System prompt: paste the German prompt
- Tool schema: paste `tool_schemas.json`
- Voice ID: the chosen ElevenLabs voice id
- Set **Active**

The dashboard's version-comparison page now uses this version as the baseline.

(Alternative if the dashboard isn't ready yet: insert directly via SQL — see the seed file for an example row.)

---

## 11. Troubleshooting checklist

| Symptom | Likely cause | Fix |
|---|---|---|
| Tool call returns 401 | `X-Auth-Secret` mismatch | Confirm both ends use the same `N8N_SHARED_SECRET` |
| Tool call returns 404 | n8n workflow inactive, or wrong path | Activate workflow; the path must match the `webhookId` in the JSON |
| Tool call returns 500 | Supabase env vars missing in n8n, or wrong RLS policy | Check `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` set in n8n; service role bypasses RLS |
| Agent doesn't ask for CES | System prompt section 7 missing or out of order | Re-paste `system_prompt.md` |
| `customer_feedback` row never appears | `submit_ces_rating` workflow returns error, or post-call placeholder not inserted | Check `submit_ces_rating` and `post_call_finalize` workflows; ensure the placeholder logic in `post_call_finalize` runs |
| KB returns wrong document for a query | Similarity threshold too low | Raise from 0.30 to 0.45 and re-test |
| Agent invents prices / dates | Temperature too high, or KB miss not handled | Drop temperature to 0.20 (start there if 0.30 isn't strict enough); check that the agent says „kann ich nicht garantiert beantworten" on KB miss |
| `outcomes` row never appears | `conversation.ended` webhook misrouted | Confirm in webhook list; payload must include `event: 'conversation.ended'` |
| No transcript on `/calls/[id]` page | turn-level webhooks not enabled, or Realtime publication missing | Enable `conversation.turn` (user) and (agent); verify `alter publication supabase_realtime add table conversation_turns;` ran |
| Tool calls succeed but `tool_calls` table empty | `tool_called`/`tool_result` webhooks not enabled | Add them and re-test |

If a problem persists after this list: capture the **conversation external_call_id**, the **Supabase row state**, and the **n8n execution log**, and walk through them in order.
