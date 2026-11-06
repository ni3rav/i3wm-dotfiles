#!/usr/bin/env bash
# Restart the i3-layouts daemon (spiral, etc.). Used by exec_always and reload.
set -euo pipefail

# Prefer exact console-script match; fall back to the module entrypoint.
pkill -f "${HOME}/.local/bin/i3-layouts" 2>/dev/null || true
pkill -f 'from i3l.cli import main' 2>/dev/null || true
sleep 0.05

exec "${HOME}/.local/bin/i3-layouts"
