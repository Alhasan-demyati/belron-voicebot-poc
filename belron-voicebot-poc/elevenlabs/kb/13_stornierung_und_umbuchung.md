---
title: Stornierung und Umbuchung — Grundregeln
category: cancellation_policy
tags: [stornierung, umbuchung, terminverschiebung]
use_cases: [1, 3, 4]
language: de
last_reviewed: 2026-04-26
---

# Stornierung und Umbuchung — Grundregeln

Termine können in der Regel kostenfrei verschoben oder storniert werden — wir bitten lediglich um rechtzeitige Information, damit der Slot anderen Kunden zur Verfügung steht.

## Empfehlungen

- **Mindestens 24 Stunden vor dem Termin** verschieben oder stornieren, idealerweise früher.
- **Am Tag des Termins** kurzfristige Änderungen sind möglich, aber bitten den Kunden, telefonisch direkt mit der Filiale zu klären.

## Was die Sprachassistentin tun darf

- **Umbuchung auf einen anderen Tag oder eine andere Uhrzeit in derselben Filiale**: ja, mit `reschedule_appointment` nach verbaler Bestätigung.
- **Stornierung**: ja, mit `cancel_appointment` nach verbaler Bestätigung; nach Möglichkeit den Grund erfragen.
- **Umbuchung mit Filialwechsel**: **nein** — die Sprachassistentin darf das nicht selbständig durchführen, weil Kapazitäten und Logistik filialspezifisch sind. → an einen Mitarbeiter weiterleiten.

## Bestätigungs-Regel (hart)

- Vor jedem Schreibvorgang muss der Kunde **explizit verbal zustimmen** (z. B. „Ja, bitte umbuchen" / „Genau"). 
- Nur dann darf das Tool aufgerufen werden — und immer mit einem `confirmation_token`, der die Bestätigung dokumentiert.

## Wann an einen Mitarbeiter weiterleiten

- **Filialwechsel** im Rahmen einer Umbuchung.
- Wiederholte Umbuchungen / sehr kurzfristige Anfragen am Tag des Termins.
- Wenn die gewünschte Slot-Konfiguration nicht im verfügbaren Angebot enthalten ist.
- Bei besonderen Stornierungsfällen (z. B. mit Versicherungsbezug).
