# UC4 — Multi-Intent Test Dialogues (German)

The most complex use case: the caller switches goals mid-conversation. UC4 is the stress test for the agent's planning + recovery logic.

> Pre-flight: same as UC3.

---

## Dialogue 4.1 — Reschedule → mid-call FAQ → back to reschedule → confirm

**Setup:** Customer Jonas Fischer (`+491701234003`) with a `scheduled` appointment.

**Caller:**
> „Ja, einverstanden."
> „Ich möchte meinen Termin verschieben — und übrigens, was kostet eigentlich die Kalibrierung?"

**Expected agent behavior:**
- Anerkennt beide Themen: „Gerne, dazu beides."
- Antwortet zuerst auf die FAQ aus der KB (Artikel 6 + 10): „Die Kalibrierung ist meistens Teil des Frontscheibenaustauschs; die genauen Kosten hängen von Ihrer Versicherung ab."
- Wechselt dann zur Umbuchung: „Und nun zur Verschiebung — können Sie mir bitte zuerst Ihre Telefonnummer nennen?"

**Caller:**
> *(Telefonnummer, Bestätigung, Wunsch-Slot)*

**Expected agent behavior:**
- Standard-UC3-Flow.

**Caller (mitten im Slot-Vorschlag):**
> „Moment, eine Frage noch — funktioniert mein Spurhalteassistent danach noch?"

**Expected agent behavior:**
- Antwortet aus KB-Artikel 6 / 22: „Ja, nach der Kalibrierung funktionieren die Fahrerassistenzsysteme wieder normal."
- Kehrt zur Umbuchung zurück: „Zurück zu Ihrem Termin — soll ich auf Donnerstag um zehn Uhr umbuchen?"

**Caller:**
> „Ja, gerne."

**Expected agent behavior:**
- `reschedule_appointment` mit `confirmation_token`.
- **Eine** CES-Frage ganz am Ende, nicht pro Sub-Goal.

**Pass criteria:**
- `tool_calls`: `get_customer_by_phone`, `check_availability`, `reschedule_appointment` — keine doppelten.
- KB-Antworten erscheinen **nicht** in `tool_calls` (KB ist intern in ElevenLabs).
- `outcomes.use_case=4` (oder 3 — beides ok), `customer_goal_completed=true`.
- **Genau 1** `customer_feedback`-Zeile.

---

## Dialogue 4.2 — Reschedule → cancel → back to reschedule

**Setup:** Same as 4.1.

**Caller:**
> *(läuft den UC3-Flow bis zum Bestätigungs-Schritt)*
> Agent: „Soll ich auf zehn Uhr umbuchen?"

**Caller:**
> „Eigentlich — kann ich auch direkt stornieren?"

**Expected agent behavior:**
- Wechselt zu Cancel-Flow: „Klar. Möchten Sie den Termin am [Datum/Uhrzeit] in [Filiale] stornieren?"

**Caller:**
> „Hmm, doch nicht. Lassen Sie uns umbuchen."

**Expected agent behavior:**
- Kehrt zum Reschedule-Flow zurück, ohne Daten zu vergessen: „In Ordnung — soll ich also auf zehn Uhr umbuchen?"

**Caller:**
> „Ja."

**Expected agent behavior:**
- `reschedule_appointment` mit Bestätigungs-Token.
- CES → `end_call`.

**Pass criteria:**
- **Kein** `cancel_appointment` Tool-Call (der Kunde hat zurückgezogen).
- 1 `reschedule_appointment` Tool-Call.
- `appointment_history`: nur die neue Reschedule-Zeile, kein Cancel-Eintrag.

---

## Dialogue 4.3 — Reschedule → echte Cancellation → bestätigen

**Setup:** Same as 4.1.

**Caller:**
> „Ich wollte verschieben — eigentlich, weiß ich nicht, vielleicht stornieren?"

**Expected agent behavior:**
- Klärt: „Möchten Sie verschieben oder stornieren?"

**Caller:**
> „Stornieren bitte."

**Expected agent behavior:**
- Identifikation, sofern noch nicht erfolgt.
- „Soll ich Ihren Termin am [Datum/Uhrzeit] in [Filiale] **stornieren**?"

**Caller:**
> „Ja."

**Expected agent behavior:**
- `cancel_appointment(appointment_id=…, reason='customer_request', confirmation_token='confirmed_cancel_…')` aufrufen.
- „Erledigt, der Termin ist storniert. Möchten Sie einen neuen Termin vereinbaren?"

**Caller:**
> „Nein, danke. Auf Wiederhören."

**Expected agent behavior:**
- CES-Frage → `submit_ces_rating` → `end_call`.

**Pass criteria:**
- `appointments` Zeile: status='cancelled'.
- `appointment_history` 1 neue Zeile mit `new_status='cancelled'`, `changed_by='bot'`.
- `outcomes.use_case=4`, `automated=true`.

---

## Dialogue 4.4 — Verwirrte Customer-Konversation, mehrere Klärungsrunden, Übergabe

**Setup:** Caller is intentionally vague.

**Caller:**
> „Ja… also, ich war doch dort. Und mein Auto. Aber jetzt …"

**Expected agent behavior:**
- Klärungsfrage: „Können Sie mir bitte etwas mehr zum Anliegen sagen — geht es um einen vergangenen Termin, einen geplanten Termin, oder eine allgemeine Frage?"

**Caller:**
> „Ich glaube, es war letzten Monat. Da war was."

**Expected agent behavior:**
- Eine zweite Klärungsfrage, höchstens.
- Wenn nicht klärbar: Übergabe. „Damit Sie schnell die richtige Hilfe bekommen, verbinde ich Sie mit einem Kollegen, der das mit Ihnen klärt."
- `transfer_to_agent(reason_code='low_confidence', summary='Kunde unklar — möglicherweise Frage zu vergangenem Termin oder Reklamation. Sprache vage, nach 2 Klärungsfragen weiterhin unklar.', customer_data={})`.

**Pass criteria:**
- Maximal **2 Klärungsfragen**, dann Übergabe.
- `handovers` mit `reason_code='low_confidence'`.
- Agent erfindet nichts.
