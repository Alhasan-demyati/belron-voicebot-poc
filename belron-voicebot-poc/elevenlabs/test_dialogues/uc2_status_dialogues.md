# UC2 — Status Check Test Dialogues (German)

> Pre-flight: agent + KB + n8n live, dashboard open in second tab.

---

## Dialogue 2.1 — Happy path: known phone number → known appointment

**Setup:** Use the seeded customer Lukas Müller (`+491701234001`). Make sure he has at least one appointment with status `scheduled` or `ready_for_pickup` (the seed creates 150 appointments distributed across all 50 customers, so this is virtually certain).

**Caller:**
> „Ja, einverstanden."
> „Ich wollte mal fragen, ob mein Auto fertig ist."

**Expected agent behavior:**
- „Damit ich Ihren Datensatz finden kann — können Sie mir bitte zuerst Ihre Telefonnummer nennen?"

**Caller:**
> „Null-eins-sieben-null, eins-zwei-drei-vier, null-null-eins."

**Expected agent behavior:**
- Wiederholt die Ziffern: „Ich habe verstanden: null-eins-sieben-null, eins-zwei-drei-vier, null-null-eins. Ist das korrekt?"

**Caller:**
> „Ja."

**Expected agent behavior:**
- Ruft `get_customer_by_phone(phone='+491701234001')` auf → bekommt Lukas Müller + recent_appointments zurück.
- Wenn 1 offener Termin: liest Status vor („Ihr Fahrzeug ist abholbereit, Filiale ..." oder „Der Austausch läuft gerade, voraussichtlich fertig um ...")
- Wenn mehrere: „Geht es um den Termin am [Datum] in [Stadt]?"
- Ruft ggf. `get_appointment` auf, um die ETA zu lesen.
- CES-Frage → `submit_ces_rating` → `end_call`.

**Pass criteria:**
- `tool_calls` enthält Einträge für `get_customer_by_phone` (status=success), ggf. `get_appointment`.
- `outcomes.use_case=2`, `automated=true`.
- `customer_feedback` mit `ces_collected=true`.

---

## Dialogue 2.2 — Phone unknown → fallback per booking ref

**Setup:** Caller pretends to be a new customer not in the seed. Has a booking ref written on a card. (Use a real one from `seed.sql` — e.g. pick any `CG-XXXXX` from the appointments table.)

**Caller:**
> „Ja."
> „Ist mein Termin noch in Ordnung? Ich habe die Buchungsnummer hier."

**Expected agent behavior:**
- Bittet um die Telefonnummer.

**Caller:**
> „Null-zwei-null-null, eins-zwei-drei-vier-fünf-sechs."  *(eine Nummer, die NICHT im Seed ist)*

**Expected agent behavior:**
- Bestätigt die Ziffern, ruft `get_customer_by_phone` → `found=false`.
- Fragt nach Alternativ-ID: „Ich konnte Ihre Nummer nicht in unseren Daten finden. Können Sie mir alternativ Ihre Buchungsreferenz, Ihr Kennzeichen oder Namen und Postleitzahl nennen?"

**Caller:**
> „Buchungsreferenz CG-..."  *(eine echte aus dem Seed)*

**Expected agent behavior:**
- Ruft `find_customer(booking_ref='CG-…')` → `found=true`, customer dazu.
- Liest den Status vor (wie 2.1).
- CES-Frage.

**Pass criteria:**
- `tool_calls`: 1× `get_customer_by_phone` (found:false), 1× `find_customer` (found:true), 1× `get_appointment`.
- `outcomes.automated=true`.

---

## Dialogue 2.3 — Phone known but no open appointment

**Setup:** Pick a customer whose only appointments are in status `completed` or `cancelled` (you may need to manually `UPDATE` one in Supabase to set this up, or just pick by querying the seed).

**Caller:**
> „Ja, gerne."
> „Ist mein Auto fertig?"

**Expected agent behavior:**
- Identifikation wie in 2.1.
- `get_customer_by_phone` → customer ja, aber keine offenen Termine in `recent_appointments` (nur `completed`).
- Antwort: „Ich sehe in unserem System keinen offenen Termin für Sie. Möglicherweise haben Sie schon abgeholt — der letzte Termin steht bei uns als ‚abgeschlossen'. Kann ich Ihnen sonst weiterhelfen?"
- Caller: „Nein, danke." → CES → `end_call`.

**Pass criteria:**
- Agent erfindet **keinen** Status, sagt ehrlich, was im System steht.
- `customer_feedback` vorhanden.

---

## Dialogue 2.4 — Caller hängt mid-flow auf (CES-Capture-Test)

**Setup:** Wie 2.1.

**Caller:**
> „Ja"
> *(spricht Telefonnummer)*

**Expected agent behavior:**
- Bestätigt Ziffern.

**Caller:**
> *(legt sofort auf, ohne weitere Antwort)*

**Expected agent behavior:**
- Nach 25 Sek Stille: „Ich kann Sie leider nicht hören — auf Wiederhören." → `end_call(outcome='abandoned')`.
- `submit_ces_rating(declined=true)` falls noch möglich.

**Pass criteria:**
- `outcomes.abandoned=true`, `abandonment_stage='identification'`.
- `customer_feedback` enthält 1 Placeholder-Zeile mit `ces_collected=false` (entweder vom Agenten oder vom `post_call_finalize`-Workflow eingefügt).
