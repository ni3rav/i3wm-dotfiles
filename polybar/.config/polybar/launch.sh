#!/usr/bin/env bash
killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.1; done

for _ in $(seq 1 50); do
  i3-msg -t get_version >/dev/null 2>&1 && break
  sleep 0.1
done

command -v polybar >/dev/null || exit 0

DIR="$HOME/.config/polybar"
mapfile -t monitors < <(polybar -m 2>/dev/null)
primary=""
for line in "${monitors[@]}"; do
  name="${line%%:*}"
  if [[ "$line" == *primary* ]]; then
    primary="$name"
    break
  fi
done
[[ -z "$primary" && ${#monitors[@]} -gt 0 ]] && primary="${monitors[0]%%:*}"

if [[ -n "$primary" ]]; then
  MONITOR="$primary" polybar -q main -c "$DIR/config.ini" &
else
  polybar -q main -c "$DIR/config.ini" &
fi
