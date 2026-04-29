---
title: Wartezeiten und gleichzeitige Termine
category: appointment_basics
tags: [wartezeit, kapazitaet, gleichzeitige_termine]
use_cases: [1, 4]
language: de
last_reviewed: 2026-04-26
---

# Wartezeiten und gleichzeitige Termine

Wie schnell ein Termin verfügbar ist, hängt von der **Auslastung der Filiale** und der **Schadensart** ab.

## Typische Vorlaufzeiten

- **Steinschlag-Reparatur**: oft **am gleichen oder nächsten Tag** möglich, weil schnell durchführbar.
- **Frontscheiben-Austausch ohne Sonderscheibe**: typischerweise **innerhalb 1 bis 3 Tagen**, da die Standardscheibe regional verfügbar ist.
- **Frontscheiben-Austausch mit Sonderscheibe** (Akustikglas, beheizbare Scheibe, Sondermodell): **3 bis 7 Tage**, da Bestellung nötig ist.
- **Mobiler Service**: regionale Schwankungen — kann auch ein paar Tage Vorlauf haben.

## Mehrere Termine parallel

Eine Filiale kann üblicherweise **2 bis 4 Termine gleichzeitig** durchführen, abhängig von der Anzahl der Werkstattbuchten und Techniker. Carglass-Filialen verteilen die Slots so, dass keine zwei Frontscheiben-Austausche denselben Klebstoff-Trocknungs-Slot blockieren.

## Was die Sprachassistentin tun darf

- Eine grobe Vorlaufzeit nennen, basierend auf der Schadensart.
- Das interne Buchungssystem (`check_availability`) abfragen, um konkrete freie Slots zu nennen.
- Den Kunden über erwartete Wartezeiten ehrlich informieren.

## Wann an einen Mitarbeiter weiterleiten

- Bei **dringenden Anfragen** (z. B. „Kann ich noch heute kommen?", wenn das System keine Slots zeigt).
- Wenn der Kunde Sonderausstattung mitbringt, die längere Lieferzeiten verursachen könnte.
- Bei Anfragen für mehrere Fahrzeuge gleichzeitig (Flotte, Firmenwagen).
