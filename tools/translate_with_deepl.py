#!/usr/bin/env python3
"""
Fill empty English slots in Localizable.xcstrings via DeepL API.

Setup:
1. Get a free DeepL API key: https://www.deepl.com/pro-api (500 000
   characters / month free, key ends with ":fx").
2. Put the key in `~/.deepl-key` (single line) **or** export
   `DEEPL_API_KEY=…` in the environment.

What it does:
- Loads Sources/HAMRechner/Content/Localizable.xcstrings.
- Collects every entry where the EN slot has empty value or state="new".
- Wraps Swift string-interpolation `\\(name)` in `<x>…</x>` XML tags so
  DeepL leaves them untouched (`tag_handling=xml`).
- Batches up to 30 strings per request, calls the v2 API, writes results
  back with `state="needs_review"` so a human can sign off.
- Saves the catalog after every batch — safe to interrupt with Ctrl+C.

The "needs_review" marker keeps the translation visible (SwiftUI uses it)
but signals that it hasn't been hand-verified. Once you've sanity-checked
a batch in Xcode's Catalog editor, flip them to "translated" manually.

Usage:
    python3 tools/translate_with_deepl.py [--dry-run] [--limit N]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = REPO_ROOT / "Sources" / "HAMRechner" / "Content" / "Localizable.xcstrings"

TARGET_LANG = "EN-US"      # American English — DeepL also has "EN-GB"
SOURCE_LANG = "DE"
BATCH_SIZE = 30            # DeepL accepts up to 50, conservative for retries
API_DELAY_SEC = 0.5        # gentle pacing
# Token-Schutz für Swift-Interpolation `\(…)`. XML-Tag-Approach war fragil,
# weil Source-Strings selbst `<`/`>` enthalten können (Vergleichsoperatoren,
# Markup-Beispiele). Stattdessen ersetzen wir Interpolationen durch eindeutige
# Token-Strings, die DeepL als Eigennamen unverändert lässt.
TOKEN_PREFIX = "ZQZQ"   # unwahrscheinlich, dass DeepL das übersetzt
TOKEN_SUFFIX = "QZQZ"

INTERPOLATION_RE = re.compile(r"\\\([^)]*\)")  # matches \(foo) and \(foo.bar)


def get_api_key() -> str:
    env_key = os.environ.get("DEEPL_API_KEY", "").strip()
    if env_key:
        return env_key
    key_file = Path.home() / ".deepl-key"
    if key_file.exists():
        return key_file.read_text(encoding="utf-8").strip()
    sys.exit(
        "[error] No DeepL API key found.\n"
        "  Either export DEEPL_API_KEY=… or put it in ~/.deepl-key (single line).\n"
        "  Get a free key at https://www.deepl.com/pro-api"
    )


def deepl_endpoint(key: str) -> str:
    # Free-tier keys end with ":fx"; the API URL differs for free vs. paid.
    return ("https://api-free.deepl.com/v2/translate" if key.endswith(":fx")
            else "https://api.deepl.com/v2/translate")


def protect_interpolation(s: str) -> tuple[str, list[str]]:
    """Replace each `\\(…)` with a numbered token (`ZQZQ0QZQZ`, `ZQZQ1QZQZ`, …)
    and return (protected_text, originals_in_order). DeepL leaves tokens of
    that shape untouched. After translation we substitute the originals back."""
    originals: list[str] = []

    def _sub(match: re.Match) -> str:
        idx = len(originals)
        originals.append(match.group(0))
        return f"{TOKEN_PREFIX}{idx}{TOKEN_SUFFIX}"

    return INTERPOLATION_RE.sub(_sub, s), originals


def unprotect_interpolation(s: str, originals: list[str]) -> str:
    out = s
    for idx, original in enumerate(originals):
        out = out.replace(f"{TOKEN_PREFIX}{idx}{TOKEN_SUFFIX}", original)
    return out


def needs_translation(entry: dict) -> bool:
    if entry.get("extractionState") == "stale":
        return False
    loc = entry.get("localizations", {})
    en = loc.get("en")
    if en is None:
        return True
    unit = en.get("stringUnit", {})
    state = unit.get("state", "")
    value = unit.get("value", "")
    if state == "new" or not value.strip():
        return True
    return False


def make_ssl_context() -> ssl.SSLContext:
    """macOS-Stock-Python verlässt sich auf den System-Cert-Store, der ohne
    `Install Certificates.command`-Run fehlt — dann scheitert HTTPS mit
    CERTIFICATE_VERIFY_FAILED. Wir versuchen erst certifi (wenn installiert),
    sonst den System-Trust-Store via `ssl.create_default_context()`. Wenn
    beides nicht greift, fällt der User auf eine klare Fehlermeldung."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    # macOS hat unter /etc/ssl/cert.pem typischerweise einen Stamm-Cert-Bundle
    macos_bundle = "/etc/ssl/cert.pem"
    if Path(macos_bundle).exists():
        ctx = ssl.create_default_context(cafile=macos_bundle)
        return ctx
    return ssl.create_default_context()


SSL_CONTEXT = make_ssl_context()


def call_deepl(texts: list[str], key: str) -> list[str]:
    # Header-based auth (DeepL hat seit Mitte 2025 die Form-Body-Variante
    # deaktiviert). Auth-Token kommt als `DeepL-Auth-Key`-Header rein.
    # Keine `tag_handling`-Option — wir schützen Interpolationen via
    # Token-Substitution (siehe protect_interpolation()).
    body_pairs = [("source_lang", SOURCE_LANG),
                  ("target_lang", TARGET_LANG),
                  ("preserve_formatting", "1")]
    for t in texts:
        body_pairs.append(("text", t))
    data = urllib.parse.urlencode(body_pairs).encode("utf-8")
    req = urllib.request.Request(
        deepl_endpoint(key),
        data=data,
        headers={
            "Authorization": f"DeepL-Auth-Key {key}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30, context=SSL_CONTEXT) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        sys.exit(f"[error] DeepL HTTP {e.code}: {body[:200]}")
    return [t["text"] for t in payload.get("translations", [])]


def chunked(items, size):
    for i in range(0, len(items), size):
        yield items[i : i + size]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true",
                        help="Show how many strings would be sent, then exit.")
    parser.add_argument("--limit", type=int, default=None,
                        help="Translate at most N strings (for testing).")
    args = parser.parse_args()

    key = get_api_key()
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    strings = catalog.get("strings", {})

    todo = [(k, entry) for k, entry in strings.items()
            if needs_translation(entry)]
    todo.sort(key=lambda kv: kv[0])

    if args.limit:
        todo = todo[: args.limit]

    print(f"[i18n-deepl] {len(todo)} strings need EN translation")
    if args.dry_run or not todo:
        print(f"[i18n-deepl] (dry run — no API calls)")
        return 0

    # Total chars for budget visibility
    total_chars = sum(len(k) for k, _ in todo)
    print(f"[i18n-deepl] ~{total_chars} source characters, "
          f"DeepL free monthly limit is 500 000")

    translated = 0
    failures = 0
    for batch_idx, batch in enumerate(chunked(todo, BATCH_SIZE), start=1):
        keys = [k for k, _ in batch]
        protected_with_originals = [protect_interpolation(k) for k in keys]
        protected_texts = [p for p, _ in protected_with_originals]
        originals_list = [orig for _, orig in protected_with_originals]
        try:
            results = call_deepl(protected_texts, key)
        except SystemExit:
            raise
        except Exception as e:
            print(f"[i18n-deepl] batch {batch_idx} failed: {e}; skipping")
            failures += len(batch)
            continue
        for key_str, raw_en, originals in zip(keys, results, originals_list):
            en = unprotect_interpolation(raw_en, originals)
            entry = strings[key_str]
            loc = entry.setdefault("localizations", {})
            loc["en"] = {"stringUnit": {"state": "needs_review", "value": en}}
            translated += 1
        # Persist after every batch so Ctrl+C doesn't lose progress
        CATALOG_PATH.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(f"[i18n-deepl] batch {batch_idx}: {len(batch)} translated "
              f"(total {translated}/{len(todo)})")
        time.sleep(API_DELAY_SEC)

    print(f"[i18n-deepl] done: {translated} translated, {failures} failed")
    print(f"[i18n-deepl] all translations marked state=needs_review — "
          f"review them in Xcode's Catalog editor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
