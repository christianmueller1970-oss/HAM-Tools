# HAM-Tools — Server-Setup für das Update-System

Diese Dokumentation beschreibt das einmalige Setup auf
`toolbox.funkwelt.net` (Hostinger VPS, Debian 12), damit das
Auto-Update der HAM-Tools-App funktioniert.

## URL-Struktur

| Datei | URL | Server-Pfad (Beispiel) |
|---|---|---|
| Manifest | `https://toolbox.funkwelt.net/app/updates.json` | `/var/www/toolbox/app/updates.json` |
| DMG-Downloads | `https://toolbox.funkwelt.net/app/dmg/HAM-Tools-X.Y.Z.dmg` | `/var/www/toolbox/app/dmg/` |

## Einmaliges Setup (auf dem Server)

```bash
# als root oder mit sudo
mkdir -p /var/www/toolbox/app/dmg
chown -R www-data:www-data /var/www/toolbox/app
chmod -R 755 /var/www/toolbox/app
```

### nginx-Snippet (falls noch nicht aktiv)

```nginx
location /app/ {
    # Manifest immer als JSON ausliefern, kein Cache
    location = /app/updates.json {
        add_header Cache-Control "no-cache, must-revalidate";
        types { application/json json; }
    }
    # DMGs als Binary, mit Cache (immutable filename)
    location /app/dmg/ {
        add_header Cache-Control "public, max-age=86400";
    }
}
```

nginx reloaden: `sudo nginx -t && sudo systemctl reload nginx`

## Pro Release (jede neue App-Version)

1. **Lokal**: `./build-dmg.sh X.Y.Z` baut HAM-Tools-X.Y.Z.dmg
2. **DMG hochladen**:
   ```bash
   scp HAM-Tools-X.Y.Z.dmg hb9hji@toolbox.funkwelt.net:/var/www/toolbox/app/dmg/
   ```
3. **Update-Manifest erzeugen**:
   ```bash
   cd tools/HAMToolsLicenseGen && swift run
   ```
   - Tab »Update-Manifest« wählen
   - Version, Build-Datum, DMG-URL, Release-Notes ausfüllen
   - »updates.json erzeugen« → »In Datei sichern…«
4. **Manifest hochladen**:
   ```bash
   scp updates.json hb9hji@toolbox.funkwelt.net:/var/www/toolbox/app/
   ```

Die installierten Apps holen das neue Manifest automatisch beim nächsten
Start (max 1× / 24h) oder bei manuellem Check via **⌘⌥U** im Menü.

## Sicherheit

- Die `updates.json` ist **Ed25519-signiert** mit demselben Schlüssel wie
  die Lizenzen. Selbst wenn jemand die Datei auf dem Server überschreiben
  könnte (z.B. via gestohlene SSH-Zugangsdaten), würde die Signatur nicht
  mehr passen und die App den Inhalt verwerfen.
- Voraussetzung: der `LicenseCrypto.publicKeyBase64` in der App ist gesetzt.
  Bei leerem Public Key schlägt der Update-Check fehl (sicher per default).
- DMGs sind selbst **ad-hoc code-signiert** (s. `build-dmg.sh`). Für
  echte Apple-Notarisierung müsste der Developer-ID-Application-Cert
  in den `codesign --sign`-Aufruf eingehängt werden — kommt später.

## Rollback

Wenn ein Release fehlerhaft ist, einfach die `updates.json` durch das
vorherige Manifest ersetzen — installierte Apps sehen das alte Build
und melden »kein Update verfügbar« beim nächsten Check. Die fehlerhafte
DMG kann im `/dmg/`-Ordner bleiben (alte Manifeste linken eh nicht
darauf).

## Test des Update-Systems lokal (ohne Server)

```bash
# 1. Manifest im Helper erzeugen, als updates.json speichern
# 2. Lokalen HTTP-Server starten:
python3 -m http.server 8080
# 3. BuildInfo.updateManifestURL temporär auf http://localhost:8080/updates.json
#    setzen, App bauen + starten — sollte das Update finden.
```
