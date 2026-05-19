#!/usr/bin/env python3
"""
Seed initial English translations for the most visible HAM-Tools UI strings.

This is a *manual* seed list — for full machine translation of the remaining
~800 keys, plug in DeepL/OpenAI/etc. later. The strings here cover top-menu
items, tab labels, common buttons, and the most-clicked dialog texts. Picked
by hand so the English skin looks decent right after the initial migration
even without further translation work.

Run after extract_strings.py to merge translations into the catalog.

Usage:
    python3 tools/seed_en_translations.py
"""

from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = REPO_ROOT / "Sources" / "HAMRechner" / "Content" / "Localizable.xcstrings"

# Seed-Mapping: deutscher Source-Key → englische Übersetzung.
# Manuell kuratiert für die sichtbarsten ~80 Strings. Strings die wörtlich
# gleich bleiben (Eigennamen, Fachbegriffe) tauchen hier nicht auf — die
# füllen wir später nach Bedarf.
SEEDS: dict[str, str] = {
    # --- Top-Menü + Globale Aktionen ---
    "Abbrechen": "Cancel",
    "OK": "OK",
    "Speichern": "Save",
    "Schließen": "Close",
    "Weiter": "Next",
    "Zurück": "Back",
    "Löschen": "Delete",
    "Bearbeiten": "Edit",
    "Hinzufügen": "Add",
    "Entfernen": "Remove",
    "Anwenden": "Apply",
    "Übernehmen": "Apply",
    "Zurücksetzen": "Reset",
    "Aktualisieren": "Refresh",
    "Jetzt aktualisieren": "Update now",
    "Später": "Later",
    "Nicht mehr fragen": "Don't ask again",
    "Anlegen": "Create",
    "Übersicht": "Overview",
    "Einstellungen …": "Settings…",
    "Auf Updates prüfen…": "Check for updates…",

    # --- Settings-Tabs ---
    "Station": "Station",
    "Cluster": "Cluster",
    "Daten": "Data",
    "Lookup & Upload": "Lookup & Upload",
    "Darstellung": "Appearance",
    "Alerts": "Alerts",
    "CAT": "CAT",
    "Externe Logger": "External Loggers",
    "Lizenz": "License",

    # --- Logbuch-Tabs ---
    "Log": "Log",
    "Map": "Map",
    "Bands": "Bands",
    "DXClusters": "DX Clusters",
    "Awards": "Awards",
    "Stats": "Stats",
    "QSL": "QSL",
    "History": "History",
    "Memories": "Memories",
    "Contest-Map": "Contest Map",

    # --- QSO-Form ---
    "Call": "Call",
    "First": "First",
    "Last": "Last",
    "Street": "Street",
    "City": "City",
    "County": "County",
    "State": "State",
    "Country": "Country",
    "Email": "Email",
    "Notes": "Notes",
    "Time On": "Time On",
    "Time Off": "Time Off",
    "Mode": "Mode",
    "Band": "Band",
    "Power": "Power",
    "Locator": "Locator",
    "QSL Via": "QSL Via",
    "DX de": "Spotter",

    # --- Log-Aktionen ---
    "Log QSO": "Log QSO",
    "Stacking": "Stacking",
    "Sent": "Sent",
    "Recv": "Recv",
    "Run": "Run",
    "S&P": "S&P",
    "Pflichtfelder: Call + Frequenz": "Required: Call + Frequency",

    # --- Status / States ---
    "aktiv": "active",
    "lauschend": "listening",
    "gestoppt": "stopped",
    "Fehler": "Error",
    "aus": "off",
    "startet …": "starting…",
    "Neues Log anlegen": "Create new log",

    # --- Update-System ---
    "HAM-Tools ist aktuell": "HAM-Tools is up to date",
    "Update-Check fehlgeschlagen": "Update check failed",
    "Upload fehlgeschlagen": "Upload failed",
    "Verwerfen": "Discard",
    "QRZ-Profil öffnen": "Open QRZ profile",

    # --- Daten-Tab + Datenbanken ---
    "Datenordner": "Data folder",
    "Im Finder zeigen": "Show in Finder",
    "Ordner wählen …": "Choose folder…",
    "Auf Standard zurücksetzen": "Reset to default",
    "Struktur": "Structure",
    "Bestandsaufnahme": "Inventory",
    "Master Call Database (Contest-Suggest)": "Master Call Database (Contest Suggest)",
    "Alle aktualisieren": "Refresh all",
    "Aktualisiere …": "Refreshing…",
    "deaktiviert": "disabled",
    "noch nie aktualisiert": "never refreshed",
    "aus App-Bundle": "from app bundle",
}


def main() -> int:
    data = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    strings = data.get("strings", {})

    updated = 0
    skipped_missing = 0
    skipped_existing = 0

    for de_key, en_value in SEEDS.items():
        entry = strings.get(de_key)
        if entry is None:
            skipped_missing += 1
            continue
        loc = entry.setdefault("localizations", {})
        en_slot = loc.setdefault("en", {"stringUnit": {"state": "new", "value": ""}})
        existing = en_slot.get("stringUnit", {}).get("value", "")
        if existing and existing != en_value:
            skipped_existing += 1
            continue
        en_slot["stringUnit"] = {"state": "translated", "value": en_value}
        updated += 1

    CATALOG_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"[i18n-seed] {updated} EN-translations written")
    print(f"[i18n-seed] {skipped_existing} already had different EN-text (kept)")
    print(f"[i18n-seed] {skipped_missing} seed keys NOT in catalog (out-of-date?)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
