# Knowledge Base — upload to ElevenLabs

This folder contains 30 German articles ready to upload into the ElevenLabs Knowledge Base attached to the Remona DE PoC agent. The agent retrieves from these for **general** questions (UC1, UC4) — FAQs, glass types, insurance basics, calibration explainer, prerequisites, etc.

> Branch-specific facts (real opening hours of a specific city, an actual appointment) come from Supabase tools, **not** from the KB. The system prompt enforces this distinction.

## Upload steps

1. In the ElevenLabs UI, open your agent → **Knowledge Base** tab.
2. Click **Upload documents**.
3. Drag-and-drop the 30 files from this folder (`01_*.md` … `30_*.md`).
4. Wait for indexing (1–2 minutes).
5. Set retrieval to **semantic** with chunk size `512`, overlap `64`, top-K `3`, similarity threshold `0.30`.
6. Save and attach to the agent.

## Categories (used as tags)

Each article's frontmatter declares a `category` and `tags` array. The 15 categories used:

`hours`, `locations`, `glass_types`, `insurance`, `prereq`, `calibration`, `repair_vs_replace`, `damage_response`, `process_duration`, `costs`, `vehicle_eligibility`, `appointment_basics`, `cancellation_policy`, `data_privacy`, `general_faq`

## Body structure

Each article is structured the same way:

1. **Short summary** (2–3 sentences) — what this is about.
2. **Bullet points** — concrete details, numbers, conditions.
3. **„Wann an einen Mitarbeiter weiterleiten:"** — explicit handover trigger conditions, written so the LLM understands when to escalate.

This structure helps semantic retrieval and keeps the agent grounded.

## Test queries (after upload)

Try these in the ElevenLabs test console after the upload finishes — each should retrieve the listed article and produce a grounded answer:

| German query | Expected article |
|---|---|
| „Was ist Kalibrierung?" | `06_kalibrierung.md` |
| „Was tun bei einem Steinschlag?" | `08_steinschlag_was_tun.md` |
| „Wie lange dauert ein Termin?" | `09_dauer_und_ablauf.md` |
| „Brauche ich meine Versicherungskarte?" | `26_was_bringe_ich_zum_termin_mit.md` |
| „Was kostet das?" | `10_kosten_und_selbstbeteiligung.md` |
| „Übernimmt die Versicherung?" | `04_versicherung.md` |

## Versioning

Keep this folder under git. After any edit, re-upload the affected file in the ElevenLabs UI (drag the updated file → it replaces the existing one with the same name). The ElevenLabs side is the source of truth at runtime; the git copy is the source of truth for review.

## Important caveat

The content adapts publicly observable Carglass DE patterns and is **not legally vetted**. Before going live with real customers, have your DE legal/compliance team review every article — especially the insurance, cost, and policy ones.
