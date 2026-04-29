# Handover Contract

When the agent escalates to a human, what gets passed and how to handle it.

## What gets written

A row in `handovers`:

| Field | Value |
|---|---|
| `conversation_id` | the active conversation |
| `reason_code` | enum: `location_change`, `out_of_scope`, `customer_request`, `low_confidence`, `repeated_failure`, `customer_not_found`, `safety`, `other` |
| `summary_for_agent` | 1–3 sentence German prose summary written by the agent |
| `customer_data_snapshot` | jsonb with name, phone, booking_ref, etc. |
| `qualified` | boolean — true if summary ≥ 20 chars AND name or phone is present |
| `transferred_to` | queue/team identifier (POC default: `queue:carla-de-overflow`) |

## What "qualified" means

A handover is **qualified** when the human agent picking it up has enough context to continue without re-asking the caller for basic identification. The bot's job is to never hand over a conversation the human will perceive as a cold start.

Concretely, a qualified handover must include in `summary_for_agent`:
- **Who** the caller is (name or "Anrufer mit Nummer +49…").
- **What** they want (in 1 sentence).
- **What's been tried** (which tools were called, which step failed or was reached).
- **What's needed** (what specifically the human should do next).

Example (qualified):

> „Lukas Müller (+491701234001) möchte den Termin CG-7K9F2 vom 8.5. um 10 Uhr in München Schwabing umbuchen — auf den 9.5. um 14 Uhr in München Pasing. Filialwechsel — kann ich nicht selbständig durchführen, bitte manuell prüfen und mit Kunde bestätigen."

Example (not qualified):

> „Kunde will Hilfe."

## Reason codes — when to use which

| `reason_code` | When the agent uses it |
|---|---|
| `location_change` | Caller wants to change the **branch** of an existing booking (UC3-specific block: bot can't do it). |
| `out_of_scope` | Caller asks for something the bot must not handle: legal/medical/insurance-detail advice, complex policy interpretation, anything not Carglass-related. |
| `customer_request` | Caller explicitly asks for a human ("Können Sie mich verbinden?"). |
| `low_confidence` | After 2 clarifying questions the bot still doesn't understand the request. |
| `repeated_failure` | Same tool failed twice — likely a system issue rather than a bot logic problem. |
| `customer_not_found` | Phone number, license plate, and booking ref all yielded no match — agent should manually verify identity. |
| `safety` | Caller mentions accident, smoke, glass injury, or any urgent situation. Highest priority. |
| `other` | Catch-all. The summary should explain. |

## The receiving agent's UI

In the dashboard's `/handovers` page, each handover shows:
- Time + linked conversation (one click takes the agent to the live transcript).
- Reason code as a chip.
- Qualified / not-qualified badge.
- The full summary in a quoted block.
- Optional: `agent_quality_feedback` form to rate the handover quality (used by `kpi_handover_quality`).

## Telephony bridge (deferred)

In the POC, `transfer_to_agent` only writes the handover row to Supabase. Real telephony bridging — actually transferring the live audio to a human queue — is out of scope.

When telephony is wired:
1. The `transfer_to_agent` n8n workflow gains an additional node that calls the telephony provider's `/transfer` endpoint with the queue and the call sid.
2. The agent's phrase „Ich verbinde Sie mit einem Kollegen, einen Moment bitte." plays once before the transfer; the agent then exits the conversation.

Until then: the handover is logged, the call ends with a polite goodbye, and the human team works through the queue from the dashboard.

## CES and handovers

After a handover, **the bot does not ask CES**. The receiving human takes over the conversation. If the human's call concludes successfully and the human wants to record CES feedback, it goes via the agent-side feedback flow (`agent_quality_feedback`), not via `customer_feedback.source='in_call'`.

This keeps CES averages clean: only **bot-resolved** conversations contribute to the bot's CES average. Mixed-resolution calls go into the qualified-handover quality measure instead.
