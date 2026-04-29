# UC3 — Rescheduling Test Dialogues (German)

> Pre-flight: agent + KB + n8n live; pick a customer who has an upcoming `scheduled` appointment (most seeded customers do).

---

## Dialogue 3.1 — Happy path: reschedule within same branch

**Setup:** Customer Anna Schmidt (`+491701234002`) with a `scheduled` appointment in the next 14 days. Note its booking_ref before the call.

**Caller:**
> „Ja, einverstanden."
> „Ich wollte einen Termin verschieben."

**Expected agent behavior:**
- Identifikation: „Damit ich Ihren Datensatz finden kann — Ihre Telefonnummer bitte?"

**Caller:**
> „Null-eins-sieben-null, eins-zwei-drei-vier, null-null-zwei."
> Bestätigt die Ziffern auf Nachfrage mit „Ja".

**Expected agent behavior:**
- `get_customer_by_phone` → found.
- Wenn mehrere Termine: „Welcher Termin soll verschoben werden — der am [...] oder der am [...]?"
- Wenn einer: „Ich sehe Ihren Termin am [Datum] um [Uhrzeit] in [Filiale]. An welchem Tag oder zu welcher Uhrzeit würde es Ihnen besser passen?"

**Caller:**
> „Hätten Sie was am Donnerstag Vormittag?"

**Expected agent behavior:**
- Ruft `check_availability(branch_id=<aktuelle Filiale>, service_id=<aus Termin>, from_date='Donnerstag früh', to_date='Donnerstag mittag')` auf.
- Liest 2–3 Slots: „Ich hätte am Donnerstag um neun Uhr, um zehn Uhr oder um elf Uhr dreißig. Welcher passt?"

**Caller:**
> „Zehn Uhr passt."

**Expected agent behavior:**
- Bestätigung holen: „Soll ich Ihren Termin auf Donnerstag, den [Datum] um zehn Uhr in [Filiale] umbuchen?"

**Caller:**
> „Ja, machen Sie das."

**Expected agent behavior:**
- Ruft `reschedule_appointment(appointment_id=…, new_start='…T10:00:00+02:00', confirmation_token='confirmed_…')` auf.
- Antwort vom n8n: ok=true.
- „Erledigt. Ihr neuer Termin ist am Donnerstag, den [Datum] um zehn Uhr in [Filiale]."
- CES-Frage → `submit_ces_rating` → `end_call`.

**Pass criteria:**
- `tool_calls`: get_customer_by_phone, list_appointments (oder direkt aus get_customer_by_phone), check_availability, reschedule_appointment — alle status=success.
- `appointments`: die Zeile hat **neue** scheduled_start.
- `appointment_history`: 1 neue Zeile mit `changed_by='bot'`, `conversation_id` gesetzt.
- `outcomes.use_case=3`, `automated=true`, `customer_goal_completed=true`.
- `customer_feedback` mit `ces_score`.

---

## Dialogue 3.2 — Filialwechsel → Übergabe

**Setup:** Same as 3.1.

**Caller:**
> „Ja."
> „Ich möchte meinen Termin verschieben — und zwar in eine andere Filiale."

**Expected agent behavior:**
- Sofort erkennen: Filialwechsel.
- „Filialwechsel kann ich leider nicht selbständig durchführen, ich verbinde Sie mit einem Kollegen."
- `transfer_to_agent(reason_code='location_change', summary='Kunde [Name] möchte Termin von [aktuelle Filiale] in eine andere Filiale verlegen.', customer_data={…})`.

**Pass criteria:**
- `handovers` 1 neue Zeile mit `reason_code='location_change'`, `qualified=true` (summary enthält Name + Anliegen).
- **Kein** `reschedule_appointment` Tool-Call.
- `outcomes.handover=true`.

---

## Dialogue 3.3 — Write-before-confirmation regression test

**Setup:** Same as 3.1.

**Caller:**
> *(durchläuft den ganzen Reschedule-Flow bis zum Vorschlag der neuen Slots)*

**Expected agent behavior:**
- Bietet 3 Slots an.

**Caller:**
> „Hmm, die zehn Uhr klingt gut, aber ich überlege noch."

**Expected agent behavior:**
- **Darf NICHT** `reschedule_appointment` aufrufen — der Kunde hat nicht „Ja" gesagt.
- „Möchten Sie sich noch ein paar Minuten Zeit nehmen oder gleich entscheiden?"

**Caller:**
> „Doch, machen wir's. Zehn Uhr."

**Expected agent behavior:**
- „Soll ich auf zehn Uhr umbuchen?"

**Caller:**
> „Ja."

**Expected agent behavior:**
- Jetzt erst `reschedule_appointment` mit `confirmation_token` aufrufen.

**Pass criteria:**
- Genau **1** `reschedule_appointment` Tool-Call.
- Falls der Agent versehentlich vorzeitig aufruft, gibt n8n `CONFIRMATION_REQUIRED` zurück und der Agent muss sich erholen (eigenes Lehrbeispiel — markiere das im Test als „Verbesserungsbedarf am Prompt").

---

## Dialogue 3.4 — Keine freien Slots → Übergabe

**Setup:** Pick a branch+service combination where you've manually inserted slot_overrides for the entire next week (closes the branch). Or test by asking for a very specific narrow window the bot can't fulfill.

**Caller:**
> *(läuft durch UC3, will Termin am Sonntag um 18 Uhr)*

**Expected agent behavior:**
- `check_availability` → `slots: []`.
- „In dem Zeitfenster habe ich leider nichts frei. Möchten Sie einen anderen Tag?"

**Caller:**
> „Nein, nur Sonntag 18 Uhr."

**Expected agent behavior:**
- Bietet Übergabe an: „Dann schauen wir mal mit einem Kollegen, ob sich was machen lässt — ich verbinde Sie."
- `transfer_to_agent(reason_code='customer_request', …)`.

**Pass criteria:**
- `tool_calls.check_availability.response_payload.data.slots` ist leer.
- `handovers` neue Zeile.
