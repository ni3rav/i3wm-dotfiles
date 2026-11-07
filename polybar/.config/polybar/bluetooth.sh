#!/usr/bin/env bash
icon="󰂲"
if command -v bluetoothctl >/dev/null; then
  powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}')
  if [[ "$powered" == "yes" ]]; then
    if bluetoothctl info 2>/dev/null | grep -q 'Connected: yes'; then
      icon="󰂰"
    else
      icon="󰂯"
    fi
  fi
fi
printf '%%{T2}%s%%{T-}\n' "$icon"
