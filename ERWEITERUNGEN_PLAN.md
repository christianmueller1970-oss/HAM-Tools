# Erweiterungen #1 — Konzept

Stand: 2026-05-15, abgestimmt mit HB9HJI. Quelle: `HAM-Tools Erweiterungen 1.pdf`.

Vier Features zur Effizienz-Steigerung im Logbuch + Mehrmonitor-Workflow.
Reihenfolge der Umsetzung wie hier nummeriert (1 → 4).

---

## 1 · Transceiver-Quick-Switch (macOS Menubar)

Schnelles Wechseln zwischen gespeicherten CAT-Configs ohne Settings-Klick.
Inspiration: RUMlog "Transceiver"-Menü.

### Scope (für jetzt)

Neues `CommandMenu("Transceiver")` in der App-Menubar mit:
- **Reset CAT** — verbindet rigctld zur aktuell aktiven Config neu (typischer Fix wenn CAT hängt oder der TRX neu gestartet wurde)
- **TRX-Setup laden ▸** — Untermenü mit allen gespeicherten Configs aus `CATSettings`. Klick aktiviert die Config, wechselt rigctld-Verbindung
- **TRX-Setup speichern…** — aktuellen rigctld-Profile-State als neuen Eintrag in `CATSettings` ablegen (Dialog mit Name)
- **TRX CAT einschalten** / **ausschalten** — Toggle, hängt am `CATController.isEnabled`

### Nicht in diesem Schritt

- Transverter-Offset (eigenes Folge-Feature später)
- TRX-modellspezifische Steuerung (K3/K4/IC-705 Sub-RX, Notch, CW-Speicher, Audio-Routing) — sind im RUMlog-Screenshot grau und bleiben für später
- Mehrere TRX parallel (TRX #1 ↔ #2) — bewusst nicht: nur **ein aktiver TRX**

### Betroffene/relevante Files

- `Sources/HAMRechner/App/HAMRechnerApp.swift` (`CommandMenu` einhängen in `.commands { … }`)
- `Sources/HAMRechner/Features/CAT/CATController.swift` (Reconnect-Logik existiert vermutlich, ggf. öffentliche API ergänzen)
- `Sources/HAMRechner/Features/CAT/CATSettings.swift` (Multi-Config existiert bereits laut Memory `feedback_cat_settings_scope` — Liste der Profile lesen)
- `Sources/HAMRechner/Features/CAT/TRXProfile.swift` (Datentyp Profile)

### Aufwand grob

S-M (1-3h). Hauptarbeit ist die saubere Verdrahtung der existierenden Multi-Config-Logik ans Menü.

---

## 2 · Bandmaps in eigenen Fenstern (Multi-Window)

Mehrere Bandmaps gleichzeitig in eigenen Pop-up-Fenstern, ideal für Mehrmonitor-Setups.

### Scope

- Im "Transceiver"-Menü (oder neuem `CommandMenu("Fenster")`?) ein Eintrag **"Neue Bandmap…"**, der ein Untermenü mit allen Bändern öffnet
- Pro Band gibt es **maximal ein** Pop-up-Fenster (zweiter Klick auf gleiches Band bringt existierendes Fenster nach vorn)
- Pop-up zeigt die existierende `BandmapView` gefiltert auf das gewählte Band
- Default-Form: **320 × 800** (schmal-hoch, mehrere passen nebeneinander auf einen Monitor)
- Datenquelle: gleicher globaler `clusterVM.spots`-Stream wie das Hauptfenster, gefiltert nach Band
- Persistenz: Position + Größe + Band werden gemerkt; offene Fenster kommen beim nächsten App-Start zurück (`SceneStorage` / `NSWindow.frameAutosaveName`)

### Offene Detail-Fragen für die Implementation

- Wie wird der globale `clusterVM` an die separaten `WindowGroup`-Scenes weitergereicht? (`@StateObject` ist am App-Level, müsste über `.environmentObject` propagiert werden)
- Single-Instance-pro-Band: registry über `@AppStorage` oder über aktives `NSWindow.title`-Scanning?

### Betroffene Files

- `Sources/HAMRechner/App/HAMRechnerApp.swift` (zusätzliche `WindowGroup` für Bandmap)
- `Sources/HAMRechner/Features/DXCluster/Views/BandmapView.swift` (muss als embeddable View funktionieren, vermutlich schon der Fall)
- Neue Datei `Sources/HAMRechner/Features/DXCluster/Views/BandmapWindow.swift` (Wrapper mit Band-Picker + WindowGroup-Glue)

### Aufwand grob

M (halber Tag). Multi-WindowGroup-Setup in SwiftUI auf macOS hat ein paar Stolpersteine (State-Sharing, Restoration).

---

## 3 · Grayline-Fenster

Tag/Nacht-Linie über der Weltkarte, mit Datum/Zeit-Picker für Propagations-Planning.

### Scope

- Eintrag im "Fenster"-Menü: **"Grayline…"** öffnet eine einzige Instanz (zweiter Klick = nach vorn holen)
- Weltkarte mit kontinuierlichem Gradient:
  - Tag = klar
  - Bürgerliche / nautische / astronomische Dämmerung als drei Abstufungen
  - Nacht = dunkel
- QTH-Marker (kleiner farbiger Punkt auf `Settings.locator`-Position, default an)
- Datum + Uhrzeit als `DatePicker` + Button **"Jetzt"** (springt auf aktuelle UTC-Zeit zurück)
- Auto-Tick: wenn das Fenster im "Jetzt"-Modus läuft, schiebt sich die Linie automatisch jede Minute
- Persistenz: Fenster-Position + Größe gemerkt

### Math

Sonnen-Subsolar-Punkt aus Datum/Zeit (Julian Date → Sun-Declination + Sun-Hour-Angle → lat/lon). Terminator-Linie = Großkreis senkrecht zum Sub-Solar-Punkt. Dämmerungs-Zonen aus Sonnen-Höhenwinkel (-6° / -12° / -18°).

Standard-Astronomie, ohne externe Lib lösbar (~50 Zeilen Math).

### Betroffene Files

- `Sources/HAMRechner/App/HAMRechnerApp.swift` (neue `WindowGroup`)
- Neue Datei `Sources/HAMRechner/Features/Grayline/Views/GraylineView.swift`
- Neue Datei `Sources/HAMRechner/Features/Grayline/SunTerminator.swift` (Math)
- Existierende Welt-Karte als Basis (POTA/SOTA/WWFF-Map nutzen sowas — Asset oder Vector?)

### Aufwand grob

M (halber bis ganzer Tag). Math ist Standard, Math+Rendering+Tick zusammen brauchen Tests.

---

## 4 · Cluster-Terminal-Fenster

Direkter Zugriff auf das Cluster-Protokoll, Befehle senden, Antworten sehen.

### Scope

- Eintrag im "Fenster"-Menü: **"Cluster-Terminal…"** öffnet eine einzige Instanz
- **Single-Cluster** — hängt am bestehenden `ClusterClient` (aktiver Cluster aus den ClusterSettings)
- UI-Layout:
  - Output-Pane: scrollable monospaced Text-Stream der Cluster-Antworten
  - Input-Feld unten mit ⏎ zum Senden
  - Schnellbefehl-Buttons-Reihe: fest verdrahtet, z.B. `sh/dx`, `dx`, `wwv`, `qrg`, `HB9HJI` (eigener Call), `Grid4`, `Grid6`, `Mgr`
  - Status-Zeile: aktiver Cluster, Verbunden-Status, Letzter Heartbeat
- Befehls-History: letzte ~50 Befehle in UserDefaults, ↑/↓ navigiert wie ein Shell-Terminal
- **Spot-Routing**: Antworten auf `sh/dx` etc. werden durch den existierenden `SpotParser` geschickt und landen wie Live-Feed-Spots im globalen `clusterVM.spots`. Das Terminal zeigt sie zusätzlich roh im Output.

### Offene Detail-Fragen für die Implementation

- Hat `ClusterClient` eine Send-API, oder muss die ergänzt werden?
- Wie unterscheidet sich "User-Befehl-Output" von "Live-Spot-Stream"? Beide kommen über dieselbe TCP-Session — ggf. Markierung via Timing oder Trigger.
- Output-Buffer-Größe (alle Zeilen halten oder Ring-Buffer von z.B. 5000 Zeilen?)

### Nicht in diesem Schritt

- Multi-Cluster mit Tabs (wie im RUMlog-Screenshot) — bewusst rausgelassen. Aufbohrbar wenn der Bedarf später klar wird
- User-konfigurierbare Schnellbefehl-Buttons (erstmal feste Liste)

### Betroffene Files

- `Sources/HAMRechner/App/HAMRechnerApp.swift` (neue `WindowGroup`)
- Neue Datei `Sources/HAMRechner/Features/DXCluster/Views/ClusterTerminalView.swift`
- `Sources/HAMRechner/Features/DXCluster/ClusterClient.swift` (Send-API ggf. ergänzen)
- `Sources/HAMRechner/Features/DXCluster/SpotParser.swift` (Wiederverwendung für `sh/dx`-Antworten)

### Aufwand grob

L (1-2 Sessions). Hauptarbeit: ClusterClient-API-Erweiterung + Output-Stream-Management + Befehls-Routing.

---

## Übergreifend

### "Fenster"-Menü vs. einzelne CommandMenus?

Drei Pop-up-Fenster (Bandmap, Grayline, Terminal) sind verwandt. Vorschlag fürs eine konsolidiertes
`CommandMenu("Fenster")` mit Untergruppe:

```
Fenster
├─ Neue Bandmap…
│   ├─ 160m
│   ├─ 80m
│   └─ … (alle Bänder)
├─ Grayline-Fenster
└─ Cluster-Terminal…
```

Plus separates `CommandMenu("Transceiver")` für TRX-Switch (das ist konzeptuell anders).

### Reihenfolge der Umsetzung

1. **TRX-Quick-Switch** (S-M) — kleinster Brocken, baut auf existierendem, schneller Erfolg
2. **Bandmaps** (M) — baut den Multi-Window-Mechanismus auf, den 3 + 4 weiter nutzen
3. **Grayline** (M) — eigenständig, dankbares visuelles Feature
4. **Cluster-Terminal** (L) — größter Brocken, profitiert vom Multi-Window-Mechanismus aus 2

Jedes Feature endet mit eigenem Commit, Help-Site-Changelog-Eintrag und (bei Release-würdigen Sets) einer neuen Version.

---

## Status

- 2026-05-15: Konzept abgestimmt.
- 2026-05-19: ✅ **Alle vier Features umgesetzt**:
  1. Transceiver-Quick-Switch — `TransceiverCommands.swift`
  2. Bandmap-Fenster — `BandmapWindowView.swift`
  3. Grayline-Fenster — `GraylineView.swift` + `SunTerminator.swift`
  4. Cluster-Terminal-Fenster — `ClusterTerminalView.swift` + `DXClusterWindowView.swift`
