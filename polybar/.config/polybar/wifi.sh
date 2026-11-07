#!/usr/bin/env bash
line=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$2=="wifi"{print; exit}')
icon="󰤮"
if [[ -n "$line" ]]; then
  IFS=: read -r _dev _type state _conn <<<"$line"
  [[ "$state" == connected* ]] && icon="󰤨"
fi
printf '%%{T2}%s%%{T-}\n' "$icon"
