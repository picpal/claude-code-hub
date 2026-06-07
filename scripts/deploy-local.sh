#!/usr/bin/env bash
# Deploy the briefing runtime OUT of ~/Desktop (TCC-protected, unreachable by launchd)
# into a non-protected location. Re-run after changing scripts/config to re-sync.
# Does NOT overwrite an existing deployed .env or dedup state.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${BRIEFING_DEPLOY_DIR:-$HOME/claudehub-briefing}"

mkdir -p "$DEST/scripts" "$DEST/config" "$DEST/.briefing-state"

# Code + config (always refreshed)
cp "$SRC"/scripts/*.py "$SRC"/scripts/*.sh "$SRC"/scripts/x_endpoints.json "$DEST/scripts/"
cp "$SRC"/config/creators.tsv "$DEST/config/"

# Dedup state seed — copy once, never clobber the live deployed state
[ -f "$DEST/.briefing-state/seen-urls.txt" ] || cp "$SRC/.briefing-state/seen-urls.txt" "$DEST/.briefing-state/seen-urls.txt" 2>/dev/null || true
[ -f "$DEST/.briefing-state/.seeded" ] || { [ -f "$SRC/.briefing-state/.seeded" ] && cp "$SRC/.briefing-state/.seeded" "$DEST/.briefing-state/.seeded"; } || true

# Secrets — copy once if present, never clobber
[ -f "$DEST/.env" ] || { [ -f "$SRC/.env" ] && cp "$SRC/.env" "$DEST/.env"; } || true

# Virtualenv — create once (venvs are not relocatable, so build in place)
if [ ! -x "$DEST/.venv/bin/python" ]; then
  python3 -m venv "$DEST/.venv"
  "$DEST/.venv/bin/pip" -q install --upgrade pip >/dev/null 2>&1 || true
  "$DEST/.venv/bin/pip" -q install requests browser_cookie3
fi

echo "Deployed briefing runtime to: $DEST"
echo "  scripts: $(ls "$DEST/scripts" | tr '\n' ' ')"
echo "  .env present: $([ -f "$DEST/.env" ] && echo yes || echo 'NO — create it')"
echo "  venv python: $DEST/.venv/bin/python"
