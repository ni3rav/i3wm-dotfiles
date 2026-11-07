#!/usr/bin/env bash
# Icon + percent for polybar; mute state only for display (click opens mixer).

case "${1:-}" in
  up)   pactl set-sink-volume @DEFAULT_SINK@ +5%; exit 0 ;;
  down) pactl set-sink-volume @DEFAULT_SINK@ -5%; exit 0 ;;
  mute) pactl set-sink-mute @DEFAULT_SINK@ toggle; exit 0 ;;
esac

muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk -F'/' 'NR==1{gsub(/%| /,"",$2); print $2; exit}')
vol=${vol:-0}

if [[ "$muted" == "yes" ]]; then
  printf '%%{T2}󰝟%%{T-} muted\n'
  exit 0
fi

if (( vol <= 30 )); then
  icon="󰕿"
elif (( vol <= 70 )); then
  icon="󰖀"
else
  icon="󰕾"
fi
printf '%%{T2}%s%%{T-} %s%%\n' "$icon" "$vol"
