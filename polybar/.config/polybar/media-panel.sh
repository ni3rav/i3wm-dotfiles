#!/usr/bin/env bash
# Compact floating media panel (yad + playerctl).

command -v playerctl >/dev/null || {
  yad --title="Media" --text="playerctl is not installed" --button=OK:0 --on-top --center --width=280
  exit 0
}

meta=$(playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null || true)
status=$(playerctl status 2>/dev/null || echo Stopped)
[[ -z "$meta" || "$meta" == " — " ]] && meta="No media playing"
[[ ${#meta} -gt 64 ]] && meta="${meta:0:61}..."

btn=$(yad --title="Media" \
  --text="<b>$status</b>\n$meta" \
  --button="󰒮:2" --button="󰐊 / 󰏤:0" --button="󰒭:3" --button="Close:1" \
  --on-top --center --width=360 --height=120 2>/dev/null) || exit 0
rc=$?

case "$rc" in
  0) playerctl play-pause 2>/dev/null || true ;;
  2) playerctl previous 2>/dev/null || true ;;
  3) playerctl next 2>/dev/null || true ;;
esac
