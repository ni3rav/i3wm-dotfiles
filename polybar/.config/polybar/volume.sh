#!/usr/bin/env bash
# Match battery spacing: icon+space in font-2, then percent.

case "${1:-}" in
  up)   exec ~/.config/i3/osd.sh volume up ;;
  down) exec ~/.config/i3/osd.sh volume down ;;
  mute) exec ~/.config/i3/osd.sh volume mute ;;
esac

muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk -F'/' 'NR==1{gsub(/%| /,"",$2); print $2; exit}')
vol=${vol:-0}

if [[ "$muted" == "yes" ]]; then
  icon="󰝟"
else
  icon="󰕾"
fi
printf '%%{T2}%s %%{T-}%s%%\n' "$icon" "$vol"
