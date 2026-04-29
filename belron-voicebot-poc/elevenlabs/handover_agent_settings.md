# Handover Agent — recommended values for the ElevenLabs UI

This is the **second** ElevenLabs Conversational AI agent that picks up calls when Remona escalates. For the POC its job is to demonstrate the handover by speaking with a clearly different (male) voice and continuing the same playbook as the primary Remona agent.

## When this agent receives a call

The primary agent (`Remona DE PoC`) calls the n8n `transfer_to_agent` webhook. n8n logs the handover and returns `target_agent_id` (this agent's ElevenLabs ID, set via the `CARGLASS_HANDOVER_AGENT_ID` n8n variable). The actual call transfer is performed via ElevenLabs' native **Agent Transfer** tool, which must be wired in the primary agent's tools panel — the n8n webhook is only the data-plane (logging + qualification + summary).

## Identity

| Field | Value |
|---|---|
| Agent name | `Remona DE — Handover (Max)` |
| Description | `Sekundärer Agent (männliche Stimme), übernimmt Übergaben vom primären Remona-Agent.` |
| Primary language | `German (de)` |
| Fallback language | `English (en)` |
| Timezone | `Europe/Berlin` |

## LLM

Same model + temperature + top-p + max-tokens as the primary agent (see [agent_settings.md](agent_settings.md)). The flow is identical from the LLM's perspective; only the voice changes.

## Voice (TTS) — male

| Field | Value | Why |
|---|---|---|
| Voice | A native German **male** voice from ElevenLabs' multilingual v2 catalogue. Recommended starting candidates: `Daniel (multilingual v2 DE)`, `Adam (multilingual v2 DE)`, or any voice marked "German native, male". Audition all and pick whichever sounds calmest. **Final choice belongs to you** — record the chosen `voice_id` in Supabase `agent_versions.voice_id`. |
| Stability | `0.50` | Same as Remona |
| Similarity boost | `0.75` | Same as Remona |
| Style exaggeration | `0.00` | Same as Remona |
| Speaker boost | `true` | Same as Remona |
| Output format | match the primary agent's output format | So audio path stays consistent on transfer |

## ASR, turn-taking, guardrails

Identical to [agent_settings.md](agent_settings.md). Re-paste the same values.

## First message (greeting on transfer)

When this agent picks up after a transfer, it should **not** greet from scratch — it already inherits context from Remona. Use a continuation greeting:

```
Hier ist Max, ich übernehme von Remona. Ich habe Ihren bisherigen Hergang. Wie kann ich Ihnen weiterhelfen?
```

(English fallback if the conversation language was English:)

```
This is Max, taking over from Remona. I have your conversation context. How can I help you?
```

## System prompt

**Use the SAME system prompt as Remona** — see [system_prompt.md](system_prompt.md). Only differences:

1. Replace the identity line "You are **Remona**" with "You are **Max**".
2. Replace the greeting in Section 4 with the continuation greeting above (you are not the entry point; you do not re-ask consent — Remona already handled it).
3. Add at the top of Section 4: "If the caller was transferred for `consent_declined`, do not record. Continue the call without recording, and do not ask consent again."

Everything else (UC1–UC5, identification, no-write-before-confirmation, handover protocol, CES, forbidden behaviors, few-shot anchors) stays identical so the caller experiences a seamless continuation with a different voice.

## Tools

Attach the **same 12 tools** from `tool_schemas.json`. Use the same n8n webhook URLs and the same `X-Auth-Secret`. The data flow is identical.

## Knowledge Base

Attach the same KB built from `elevenlabs/kb/`.

## Wiring the actual call transfer

In ElevenLabs' **primary** Remona agent, configure their built-in **Agent Transfer** capability (Conversational AI → Tools → Agent transfer). Point it at this agent's `agent_id`. Remona's `transfer_to_agent` n8n call is the **data-plane** (logs the handover, builds the summary). The **control-plane** transfer (the actual SIP/WebRTC call routing) happens via ElevenLabs's native agent-transfer tool, triggered immediately after the n8n call returns `ok: true`.

Set the n8n environment variable so the data plane and control plane agree on the target:

```
CARGLASS_HANDOVER_AGENT_ID = <agent_id of the Max agent on ElevenLabs>
```

## Save as version

After saving, copy this agent's system prompt + tool schema + voice ID into Supabase `agent_versions` with `is_active = true` and a different `version_label` (e.g., `carla-de-max-v0.1`). The dashboard's version-comparison page will then surface both Remona and Max side by side.
