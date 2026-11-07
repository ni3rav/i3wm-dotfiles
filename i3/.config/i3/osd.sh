#!/usr/bin/env bash
# Brightness/volume OSD (Windows-like bar). Does not steal focus; stays up while keys repeat.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
HUD="$SCRIPT_DIR/osd-hud.py"

case "${1:-}" in
  brightness)
    case "${2:-}" in
      up|down|show) exec python3 "$HUD" brightness "$2" ;;
      *) echo "usage: $0 brightness up|down|show" >&2; exit 1 ;;
    esac
    ;;
  volume)
    case "${2:-}" in
      up|down|mute|show) exec python3 "$HUD" volume "$2" ;;
      *) echo "usage: $0 volume up|down|mute|show" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "usage: $0 brightness|volume up|down|mute|show" >&2
    exit 1
    ;;
esac
