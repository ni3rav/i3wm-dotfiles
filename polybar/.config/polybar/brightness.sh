#!/usr/bin/env bash
# Match battery spacing: icon+space in font-2, then percent.

case "${1:-}" in
  up)   brightnessctl set +5% >/dev/null; exit 0 ;;
  down) brightnessctl set 5%- >/dev/null; exit 0 ;;
esac

cur=$(brightnessctl g 2>/dev/null) || cur=0
max=$(brightnessctl m 2>/dev/null) || max=1
(( max > 0 )) || max=1
pct=$((cur * 100 / max))

if (( pct <= 30 )); then
  icon="󰃞"
elif (( pct <= 70 )); then
  icon="󰃟"
else
  icon="󰃠"
fi
printf '%%{T2}%s %%{T-}%s%%\n' "$icon" "$pct"
