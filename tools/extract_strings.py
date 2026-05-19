#!/usr/bin/env python3
"""
Extract user-facing string literals from all .swift files in Sources/HAMRechner
and (re)build Localizable.xcstrings with German as source language.

Idempotent: existing translations are preserved across runs. New source keys
get added with empty translations (SwiftUI falls back to the source string).
Obsolete keys are kept but marked `extractionState: "stale"` so we can spot
them during review.

Usage:
    python3 tools/extract_strings.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCES_DIR = REPO_ROOT / "Sources" / "HAMRechner"
CATALOG_PATH = SOURCES_DIR / "Content" / "Localizable.xcstrings"

# Target languages (besides source). Empty string values mean "needs translation"
# — SwiftUI falls back to the German source until the slot is filled.
TARGET_LANGUAGES = ["en"]

# Patterns that we treat as user-facing SwiftUI view initializers. The capture
# group always returns the inner string literal (already de-escaped Swift
# escapes).
#
# Notes:
# * We deliberately match only first-arg literal strings — multi-line strings
#   or interpolations starting with `\(` are skipped because they need
#   per-occurrence review.
# * `Label("Foo", systemImage:`  → match
# * `Label("Foo", image:`        → match
# * `Toggle("Foo", isOn:`        → match
# * `Picker("Foo", selection:`   → match
# * `TextField("Foo", text:`     → match (placeholder)
# * `Section("Foo")`             → match
# * `Section(header: Text("Foo"))` is covered by the Text-pattern below
# * `Alert(title: Text("Foo")…)` is covered by the Text-pattern below
PATTERNS = [
    # Text("..."), Text(verbatim: "...") wir ueberspringen,
    # Text("...", comment: "...") wir nehmen nur das key-Arg
    (r'\bText\(\s*"((?:[^"\\]|\\.)*)"\s*(?:,|\))', "Text"),
    (r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"\s*,', "Label"),
    (r'\bButton\(\s*"((?:[^"\\]|\\.)*)"', "Button"),
    (r'\bToggle\(\s*"((?:[^"\\]|\\.)*)"\s*,', "Toggle"),
    (r'\bPicker\(\s*"((?:[^"\\]|\\.)*)"\s*,', "Picker"),
    (r'\bTextField\(\s*"((?:[^"\\]|\\.)*)"\s*,', "TextField"),
    (r'\bSection\(\s*"((?:[^"\\]|\\.)*)"', "Section"),
    (r'\bGroupBox\(\s*"((?:[^"\\]|\\.)*)"', "GroupBox"),
    (r'\bNavigationLink\(\s*"((?:[^"\\]|\\.)*)"', "NavigationLink"),
    (r'\.help\(\s*"((?:[^"\\]|\\.)*)"', ".help"),
    (r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"', ".navigationTitle"),
    (r'\.confirmationDialog\(\s*"((?:[^"\\]|\\.)*)"', ".confirmationDialog"),
    (r'\.alert\(\s*"((?:[^"\\]|\\.)*)"', ".alert"),
    (r'\bMenu\(\s*"((?:[^"\\]|\\.)*)"', "Menu"),
    (r'\.tabItem\s*\{[^}]*?Text\(\s*"((?:[^"\\]|\\.)*)"', ".tabItem-Text"),
    (r'\.tabItem\s*\{[^}]*?Label\(\s*"((?:[^"\\]|\\.)*)"', ".tabItem-Label"),
]

# Files / patterns we don't want to scan. Tests + scripts + 3rd-party generated.
SKIP_FILES = {
    # nothing for now — Sources/ is all first-party hand-written code
}


def looks_like_localizable(s: str) -> bool:
    """Skip pure-symbol or interpolation-only strings.

    The catalog should not collect things like "·", interpolation-only strings
    starting with `\\(`, single SF Symbol names, or one-character punctuation.
    """
    if not s.strip():
        return False
    # Pure interpolation (Swift `\(...)`) at the start: skip
    if s.startswith(r"\("):
        return False
    # Single symbol/character placeholder ("·", "—", etc.): skip
    if len(s.strip()) <= 2 and not s.strip().isalnum():
        return False
    # Looks like an SF Symbol identifier (no spaces, kebab/dot only): skip
    if re.fullmatch(r"[a-z0-9][a-z0-9.\\-]*", s.strip()):
        return False
    return True


def unescape_swift(s: str) -> str:
    """Convert Swift-source escapes back to literal characters for storage in
    the xcstrings JSON. Swift literal `\\n` → real newline, `\\\\` → `\\`,
    `\\"` → `"`, `\\(...)` we leave as-is (interpolation marker)."""
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt == "t":
                out.append("\t")
                i += 2
                continue
            if nxt == '"':
                out.append('"')
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
            # Keep other escapes (e.g. `\(...)` interpolation) verbatim
            out.append(c)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def scan_file(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    # Skip lines that are comments — `// ...` and `/* ... */` are still scanned
    # naively, but we filter out lines starting with `//` since most false
    # positives sit there.
    lines = []
    in_block_comment = False
    for line in text.splitlines():
        stripped = line.lstrip()
        if in_block_comment:
            if "*/" in line:
                in_block_comment = False
            continue
        if stripped.startswith("//"):
            continue
        if stripped.startswith("/*"):
            in_block_comment = "*/" not in line
            continue
        lines.append(line)
    scrubbed = "\n".join(lines)

    keys: set[str] = set()
    for pat, _ in PATTERNS:
        for match in re.finditer(pat, scrubbed, re.DOTALL):
            raw = match.group(1)
            key = unescape_swift(raw)
            if looks_like_localizable(key):
                keys.add(key)
    return keys


def load_existing_catalog() -> dict:
    if not CATALOG_PATH.exists():
        return {"sourceLanguage": "de", "strings": {}, "version": "1.0"}
    try:
        return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"sourceLanguage": "de", "strings": {}, "version": "1.0"}


def merge_into_catalog(catalog: dict, found_keys: set[str]) -> tuple[int, int, int]:
    """Adds new keys, marks missing keys as stale, leaves existing translations
    untouched. Returns (added, stale, kept) for reporting."""
    strings = catalog.setdefault("strings", {})
    catalog.setdefault("sourceLanguage", "de")
    catalog.setdefault("version", "1.0")

    added = 0
    kept = 0
    stale = 0
    existing = set(strings.keys())

    for key in sorted(found_keys):
        if key in strings:
            entry = strings[key]
            # Wenn frueher als stale markiert wurde aber Code es wieder hat:
            # auf "translated" zuruecksetzen
            if entry.get("extractionState") == "stale":
                entry.pop("extractionState", None)
            kept += 1
            # Stelle sicher dass alle Ziel-Sprachen-Slots existieren
            loc = entry.setdefault("localizations", {})
            for lang in TARGET_LANGUAGES:
                if lang not in loc:
                    loc[lang] = {"stringUnit": {"state": "new", "value": ""}}
        else:
            strings[key] = {
                "extractionState": "manual",
                "localizations": {
                    lang: {"stringUnit": {"state": "new", "value": ""}}
                    for lang in TARGET_LANGUAGES
                },
            }
            added += 1

    # Schluessel die nicht mehr im Code sind als stale markieren
    for key in existing - found_keys:
        entry = strings[key]
        if entry.get("extractionState") != "stale":
            entry["extractionState"] = "stale"
            stale += 1

    return added, stale, kept


def main() -> int:
    swift_files = sorted(SOURCES_DIR.rglob("*.swift"))
    found: set[str] = set()
    for path in swift_files:
        if path.name in SKIP_FILES:
            continue
        found |= scan_file(path)

    catalog = load_existing_catalog()
    added, stale, kept = merge_into_catalog(catalog, found)
    CATALOG_PATH.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"[i18n] {len(swift_files)} files scanned")
    print(f"[i18n] {len(found)} unique source keys found")
    print(f"[i18n] {added} new · {kept} existing kept · {stale} marked stale")
    print(f"[i18n] catalog: {CATALOG_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
