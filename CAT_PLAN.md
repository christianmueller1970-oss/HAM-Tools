# HAM-Tools — CAT-Anbindung (Phase 5)

**Status:** Konzept-Phase. Architektur entschieden, Detail-Implementation steht aus.
**Vorbedingung:** RadioState (Sources/HAMRechner/Features/Logbuch/Models/RadioState.swift) ist
bereits CAT-aware (`source: .manual | .cat`, `catConnected: Bool`). CAT dockt nur an.

## Entscheidungen (Q&A 2026-05-12)

| Frage | Entscheidung | Folge |
|---|---|---|
| Hamlib-Distribution | **App-Bundle (self-contained)** | Eigene Phase 5a-prep für Build-Infrastruktur |
| Initial-Rigs | **Icom IC-7300, IC-705, IC-9700** | 3 TRX-Profile zum Start, kein Yaesu/Kenwood/Elecraft |
| PTT-Control | **Später (eigene Phase 5d)** | Phase 5a/5b/5c bleiben read+write für Frequenz/Mode; PTT wenn Digi-Modes kommen |
| Hamlib-Version | **4.6.x Stable** | Tag-Pinning für reproducible Builds, z.B. `Hamlib-4.6.3` |
| Build-Architektur | **Universal2 (arm64 + x86_64)** | Build dauert länger, App läuft aber auf allen Macs der letzten ~6 Jahre |
| Codesigning | **Ad-Hoc (Dev-Phase) → Developer-ID (vor Release)** | Bestätigt 2026-05-12: User plant Verteilung als Download ab eigenem Server (kein App Store). Damit ist Developer-ID + Notarization vor dem ersten öffentlichen Release zwingend, sonst Gatekeeper-Warnung für alle Downloader. Für 5a-prep + Dev auf eigenem Mac reicht Ad-Hoc. Apple Developer Program ($99/Jahr) muss vor Release abgeschlossen sein — gilt sowohl für die HamLog-App selbst als auch für rigctld im Bundle und für signierte DMG-Auslieferung. |

---

## Architektur-Kernentscheidung

**Hamlib via `rigctld` als TCP-Subprocess** — nicht libhamlib direkt linken.

| Variante | Pro | Contra |
|---|---|---|
| **rigctld TCP** (gewählt) | Kein C-Bridging, kein Sandbox-Stress, Hamlib-Crash bringt App nicht runter, Text-Protokoll trivial zu testen, ~200 Rigs supported | Externer Prozess muss laufen + im Bundle landen |
| libhamlib FFI | Etwas weniger Latenz | Bridging-Headers, Sandbox-Komplikationen mit USB-Serial, größere App |

## Daten-Fluss

```
USB-Serial → rigctld (im App-Bundle, Port 4532) ─[TCP]→ RigctldClient (Swift)
                                                            ↓
                                                CATController (poll 500ms)
                                                            ↓
                                    RadioState (.frequencyMHz, .mode, .source = .cat)
                                                            ↓
                            QSO-Form, Send-Spot, DXCluster, RadioControlPanel, Logbuch
```

Reverse direction: User klickt Spot in DX-Cluster → `CATController.setFrequency(spot.freq)` → rigctld → Radio springt drauf.

---

## Komponenten (neu)

```
Sources/HAMRechner/Features/CAT/
├── Models/
│   ├── TRXProfile.swift          # Codable, lädt aus trx-profiles.json
│   ├── CATSettings.swift         # @AppStorage-gestützte User-Wahl (Radio, Port, Baud, Aktiv)
│   └── CATError.swift            # rigctld nicht gefunden, serial port busy, timeout, …
├── Network/
│   ├── RigctldClient.swift       # TCP-Client zu localhost:4532, Protocol-Wrapper
│   └── RigctldProcess.swift      # Lifecycle: launch / monitor / restart / stop
├── Controllers/
│   └── CATController.swift       # Orchestrator: Poll-Loop, RadioState-Sync, Reconnect
└── Views/
    ├── CATSettingsView.swift     # Radio-Picker, Port-Picker, Baud, Status, Test-Button
    └── CATStatusBadge.swift      # Mini-Indicator (Header/Panel)

Sources/HAMRechner/Content/
└── trx-profiles.json             # Hamlib-Rig-Nr, Default-Baud, Capabilities pro Modell

HAMRechner.app/Contents/Helpers/  # (Bundle-Layout)
├── rigctld                       # Hamlib-Binary, Universal2, signiert
└── lib/                          # benötigte dylibs (libhamlib, ggf. libusb)
```

## TRX-Profile (initial 3, JSON-erweiterbar)

```json
[
  {
    "id": "icom-ic7300",
    "name": "Icom IC-7300",
    "hamlibRigNumber": 3073,
    "defaultBaud": 19200,
    "defaultDataBits": 8,
    "defaultParity": "none",
    "defaultStopBits": 1,
    "supportsFreq": true,
    "supportsMode": true,
    "supportsPTT": true
  },
  {
    "id": "icom-ic705",
    "name": "Icom IC-705",
    "hamlibRigNumber": 3085,
    "defaultBaud": 115200,
    "supportsFreq": true,
    "supportsMode": true,
    "supportsPTT": true
  },
  {
    "id": "icom-ic9700",
    "name": "Icom IC-9700",
    "hamlibRigNumber": 3081,
    "defaultBaud": 115200,
    "supportsFreq": true,
    "supportsMode": true,
    "supportsPTT": true
  }
]
```

Hamlib-Rig-Numbers sind aus `rigctl --list` zu verifizieren — die obigen Werte sind nach aktueller Hamlib-Master, müssen vor Implementation gegengeprüft werden.

## rigctld-Protokoll (Referenz)

Text-basiert, eine Zeile pro Request, eine pro Response. Wichtige Commands:

| Command | Bedeutung | Antwort |
|---|---|---|
| `f` | Get VFO frequency | `14250000\n` (Hz) |
| `F <hz>` | Set frequency | `RPRT 0\n` (0 = ok) |
| `m` | Get mode + passband | `USB\n2400\n` |
| `M <mode> <pass>` | Set mode | `RPRT 0\n` |
| `t` | Get PTT (5d) | `0` oder `1` |
| `T <0\|1>` | Set PTT (5d) | `RPRT 0\n` |
| `\dump_state` | Capabilities-Discovery | mehrzeilige Caps-Liste |

Errors: `RPRT -<errcode>` (negativ = Fehler, siehe Hamlib-Doku).

---

## Phasen-Plan

| # | Phase | Inhalt | Aufwand | Output |
|---|---|---|---|---|
| **5a-prep** | ✅ **ERLEDIGT 2026-05-12** — `scripts/build-hamlib.sh` baut Hamlib 4.7.1 als Universal2 (arm64+x86_64), `--enable-static --disable-shared --without-libusb`, statisch gegen Hamlib selbst, **keine Third-Party-Dylibs** (nur libSystem + libedit aus macOS). Ad-Hoc signiert mit Hardened Runtime. Output: `vendor/hamlib/rigctld` (22.6 MB). Smoke-Test mit Dummy-Rig grün. | done | rigctld bereit fürs Bundling |
| **5a** | ✅ **ERLEDIGT 2026-05-12** — TRXProfile + trx-profiles.json (3 Icoms + Dummy-Rig für Hardware-loses Testen), RigctldProcess (launch aus Bundle-Pfad mit Dev-Fallback `vendor/hamlib/rigctld`), RigctldClient (URLSessionStreamTask), CATController (Poll-Loop + Connect-Retry 30×150 ms wegen rigctld-Bind-Race), CATSettingsView, CATStatusBadge. App-Integration via @StateObject + environmentObject. Dummy-Test live in App grün. | done | Frequenz/Mode vom Radio kommt in der App an |
| **5b** | **Write & Spot-Integration** | "Set Radio to Spot"-Button in DXClusterView (Spot anklicken → Radio QSY), Freq/Mode-Edit im RadioControlPanel pusht zu rigctld zurück | 1 Session | Bidirektionaler Sync |
| **5c** | **Polish & Robustness** | Reconnect-Strategie (USB-Yank → exponential backoff), Watchdog für rigctld-Crash, Hamlib-Install-Detection mit User-Hilfe falls Bundle-Binary fehlt, Connection-Test-Button | 1 Session | Production-tauglich |
| **5d** | **PTT-Control** (später) | `T 0/1` Befehle, "Spot-and-CQ"-Button, Foundation für Digi-Mode-Anbindung | 0.5 Sessions | PTT vom Computer aus |

**Reihenfolge zwingend:** 5a-prep blockt 5a, weil ohne Bundle-rigctld läuft nichts. 5a–5c können iterativ.

---

## Hamlib-Bundling — Strategie

Zwei Pfade, einer wird in 5a-prep evaluiert:

**A) Build-from-Source (sauber, mehr Aufwand)**
- Hamlib-Source clonen (Tag z.B. `Hamlib-4.6.x`)
- `./configure --enable-static --disable-shared --without-cxx-binding --with-rigmatrix=no` für minimalen Footprint
- Universal2: arm64 + x86_64 separat bauen, mit `lipo -create` mergen
- Output: ein statischer `rigctld` ohne externe dylib-Abhängigkeiten (außer System-Libs)
- Codesign mit Developer-ID, einbetten in Bundle

**B) Brew-rigctld einbetten (pragmatisch, schneller)**
- `brew install hamlib` lokal nutzen
- `rigctld` + benötigte dylibs (libhamlib, libusb-1.0, etc.) aus `/opt/homebrew/Cellar/hamlib/...` extrahieren
- `install_name_tool -change @loader_path/...` für relative dylib-Pfade
- Codesign alle Binaries + dylibs
- Notarization-Test obligatorisch

Empfehlung: **Variante A starten, B als Fallback** falls Build-Komplikationen.

**Risiken Bundling:**
- Universal2-Cross-Compile von libusb / Hamlib-Internals nicht immer trivial
- Notarization kann an einzelnen Dependencies hängen
- Größenwachstum App-Bundle: erwarte +5–15 MB

---

## Test-Strategie

`rigctld -m 1` startet **Dummy-Rig** ohne Hardware. Damit:
- Entwicklung von 5a/5b komplett ohne Funkgerät möglich
- Unit-Tests: RigctldClient gegen Dummy-Instanz auf Test-Port (z.B. 14532)
- CI-fähig später

Hardware-Tests mit deinem IC-7300/705/9700 erst zum Phasen-Ende für Real-World-Validation.

---

## Sandbox + Entitlements

Aktuell benötigt:
- `com.apple.security.network.client` — für localhost-TCP zu rigctld (haben wir vermutlich schon wegen DX-Cluster)
- `com.apple.security.inherit` (oder `com.apple.security.temporary-exception.files.absolute-path.read-only`) für rigctld-Child-Prozess

**Keine direkten USB-Entitlements** in der App nötig — rigctld macht die Serial-Arbeit, App spricht nur TCP. Das ist der große Win der Subprocess-Architektur.

---

## Risiken / offene Punkte

- **Build-Pipeline-Aufwand** (5a-prep) — kann sich ziehen, falls Hamlib-Cross-Build zickt. Fallback brew-Extraktion einplanen.
- **rigctld-Crash-Recovery** — USB getrennt = Process potenziell tot. Watchdog (Phase 5c) ist Pflicht.
- **Mode-Mapping** — Hamlib-Modes (`USB`/`LSB`/`CW`/`PKTUSB`/...) vs. ADIF-Modes vs. UI-Modes. Im Logbuch teils gelöst (Cabrillo), aber CAT-Mapping muss konsistent sein. Eigenes Test-Set in Phase 5a.
- **First-Run-UX bei USB** — macOS triggert beim ersten Plugin Security-Prompt für serielle Schnittstelle. Settings-UI muss das antizipieren ("Falls Verbindung scheitert: macOS-Hinweis bestätigen").
- **Yaesu/Kenwood später** — Bewusst rausgelassen, aber JSON-Profile-Architektur macht's später trivial (nur trx-profiles.json erweitern + testen).

---

## UI-Referenz (Inspiration für volle Settings-Ausbaustufe)

Vom User vorgeschlagene Referenz (Screenshot 2026-05-12, klassisches
Desktop-Logger-Layout). Im MVP (5a) noch nicht abgedeckt, aber als
Zielbild für 5c/spätere Polish-Phasen zu betrachten:

- **Hersteller + Typ als zwei-stufiger Picker** (Icom → IC-7300-Ctrl) statt
  flacher Profilliste. Hilft, wenn die Profilzahl wächst (Yaesu/Kenwood/Elecraft).
- **Interface-Auswahl**: Seriel · TCP · Bluetooth LE. Aktuell nur Seriel via
  rigctld. TCP-Hosts (z.B. Netzwerk-Rigs, FlexRadio) und BT LE-Pairing wären
  künftige Erweiterungen — Hamlib unterstützt das, wir müssten nur den Picker
  bauen und an `-r` weiterreichen.
- **XVTR Offset** (Transverter-Frequenzversatz, für VHF/UHF/SHF mit Transverter).
- **PTT-Routing-Picker**: "Für PTT nutze" — separate Wahl zwischen CAT-PTT,
  DTR, RTS, Vox, oder "Nicht nutzen". Gehört konzeptionell zu Phase 5d.
- **Transceiver-abhängig**: Mode-Mapping pro Sub-Mode (RTTY-Modus = RTTY oder
  PKTUSB? PSK-Modus = USB-Data?). Filter / Sprachspeicher pro Radio.
- **Icom Auto Discovery** (Icom hat CI-V Auto-Detect für angeschlossene Rigs).
- **Volle Serial-Parameter**: Stop bits, Parity, Flusskontrolle (RTS/CTS,
  DTR/DSR, DCD), "Leitung auf High" (RTS/DTR). Aktuell nur Baudrate exposed —
  Defaults aus dem TRX-Profil decken 99% ab, aber Power-User wollen die
  Optionen sehen.
- **TX1/TX2-Tabs**: Zweites Radio parallel konfigurierbar (für Dual-Radio
  SO2R-Workflows). Architektur-Implikation: CATController müsste mehrere
  rigctld-Instanzen auf verschiedenen TCP-Ports verwalten.
- **DxLab Suite Commander**: TCP-Bridge zu Windows-Software, irrelevant für uns.

**Take-away für 5a-MVP**: Wir bleiben minimal (1 Radio, 1 Picker, Baudrate,
Port), aber die TRX-Profile + Settings-Architektur sollten so geschnitten
sein, dass die Erweiterung später kein Rewrite ist.

---

## Out-of-Scope (kommt nicht in Phase 5)

- PTT-Control (→ 5d)
- Digi-Mode-Integration / fldigi-Bridge (Phase 6+)
- Memory-Channel-Verwaltung im Radio
- Antennen-Tuner-Steuerung (manche Rigs)
- CW-Keying via Hamlib
- DTR/RTS-PTT (nur falls jemand kein nativer-CAT-PTT-Rig hat — wir haben hier nur Icoms)

---

## Nächster Schritt — 5a-prep starten

Vorbedingungen-Check:
1. **Build-Tools installieren**: `brew install autoconf automake libtool pkg-config` (für Hamlib autotools-Build)
2. **Hamlib-Source holen**: `git clone --branch Hamlib-4.6.3 --depth 1 https://github.com/Hamlib/Hamlib.git build/hamlib-src`
3. **Erster Spike**: arm64-only-Build manuell durchziehen (`./bootstrap && ./configure --enable-static --disable-shared ... && make`), Output `rigctld` testen mit Dummy-Rig (`./rigctld -m 1`)
4. **Wenn Spike grün**: zweiter Durchgang x86_64, `lipo -create` zum Universal2-Binary, dann Bash-Script `scripts/build-hamlib.sh` daraus formalisieren
5. **Ad-Hoc-Codesign**: `codesign --force --sign - <binary>` für lokale Nutzung
6. Final: `rigctld` + ggf. Libs in App-Bundle-Layout legen, Build-DMG-Script anpassen

**Aufwand-Schätzung 5a-prep:** 1–2 Sessions wenn alles glatt läuft. Hamlib-autotools-Builds können in seltenen Fällen zicken (libusb-Dep, macOS-Spezifika) — Fallback-Plan: Brew-Extraktion (siehe Bundling-Strategie B).

---

**Erstellt:** 2026-05-12 — HB9HJI + Claude
**Vorlage:** Stil-orientiert an LOGBUCH_PLAN.md
