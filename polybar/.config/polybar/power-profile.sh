#!/usr/bin/env bash
if ! command -v powerprofilesctl >/dev/null; then
  echo "—"
  exit 0
fi

current=$(powerprofilesctl get 2>/dev/null || echo unknown)

if [[ "${1:-}" == "cycle" ]]; then
  case "$current" in
    power-saver) next=balanced ;;
    balanced) next=performance ;;
    *) next=power-saver ;;
  esac
  powerprofilesctl set "$next" >/dev/null 2>&1 || true
  current=$(powerprofilesctl get 2>/dev/null || echo "$next")
fi

case "$current" in
  performance) echo "perf" ;;
  balanced) echo "bal" ;;
  power-saver) echo "save" ;;
  *) echo "$current" ;;
esac
