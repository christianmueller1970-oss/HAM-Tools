#!/bin/bash
# sync-claude-memory.sh
# Synct Claude Code Memory zwischen Projekt-Ordner (Google Drive)
# und lokalem ~/.claude/projects/<projekt-hash>/memory/

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$PROJECT_DIR/claude-memory-backup"

# Claude Code leitet den Memory-Ordner-Namen aus dem absoluten Projekt-Pfad ab:
# Alle nicht-alphanumerischen Zeichen (außer "-") werden zu "-".
HASH="$(printf '%s' "$PROJECT_DIR" | sed 's|[^a-zA-Z0-9-]|-|g')"
MEMORY_DIR="$HOME/.claude/projects/$HASH/memory"

case "${1:-}" in
  pull)
    echo "→ Pull: $BACKUP_DIR  =>  $MEMORY_DIR"
    [ -d "$BACKUP_DIR" ] || { echo "Quelle fehlt: $BACKUP_DIR"; exit 1; }
    mkdir -p "$MEMORY_DIR"
    rsync -av --include='*.md' --exclude='*' "$BACKUP_DIR/" "$MEMORY_DIR/"
    echo "✓ Pull fertig."
    ;;
  push)
    echo "→ Push: $MEMORY_DIR  =>  $BACKUP_DIR"
    [ -d "$MEMORY_DIR" ] || { echo "Quelle fehlt: $MEMORY_DIR"; exit 1; }
    mkdir -p "$BACKUP_DIR"
    rsync -av --include='*.md' --exclude='*' "$MEMORY_DIR/" "$BACKUP_DIR/"
    echo "✓ Push fertig."
    ;;
  status)
    echo "Projekt:    $PROJECT_DIR"
    echo "Backup-Dir: $BACKUP_DIR"
    echo "Memory-Dir: $MEMORY_DIR"
    echo
    echo "--- Backup-Inhalt ---"
    ls -la "$BACKUP_DIR" 2>/dev/null || echo "  (existiert nicht)"
    echo
    echo "--- Memory-Inhalt ---"
    ls -la "$MEMORY_DIR" 2>/dev/null || echo "  (existiert nicht)"
    ;;
  *)
    cat <<EOF
Verwendung: $0 <pull|push|status>

  push   - Lokales Claude-Memory  →  Google-Drive-Backup
           (auf dem ALTEN Mac vor dem Wechsel ausführen)
  pull   - Google-Drive-Backup    →  lokales Claude-Memory
           (auf dem NEUEN Mac nach Drive-Sync ausführen)
  status - Zeigt beide Verzeichnisse mit Inhalt

Typischer Mac-Wechsel:
  [alter Mac]   ./sync-claude-memory.sh push
  (warten bis Google Drive auf neuem Mac fertig synct ist)
  [neuer Mac]   ./sync-claude-memory.sh pull
EOF
    exit 1
    ;;
esac
