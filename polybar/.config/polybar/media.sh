#!/usr/bin/env bash
# Compact prev / play-pause / next. Hidden when nothing is playing/paused.

self="$HOME/.config/polybar/media.sh"

case "${1:-}" in
  prev)   playerctl previous 2>/dev/null || true; exit 0 ;;
  next)   playerctl next 2>/dev/null || true; exit 0 ;;
  toggle) playerctl play-pause 2>/dev/null || true; exit 0 ;;
esac

command -v playerctl >/dev/null || exit 0

status=$(playerctl status 2>/dev/null || true)
# No active session → print nothing so the module disappears
[[ "$status" == "Playing" || "$status" == "Paused" ]] || exit 0

case "$status" in
  Playing) mid="󰏤" ;;
  *)       mid="󰐊" ;;
esac

printf '%%{A1:%s prev:}%%{T2}󰒮%%{T-}%%{A}%%{O6}%%{A1:%s toggle:}%%{T2}%s%%{T-}%%{A}%%{O6}%%{A1:%s next:}%%{T2}󰒭%%{T-}%%{A}\n' \
  "$self" "$self" "$mid" "$self"
