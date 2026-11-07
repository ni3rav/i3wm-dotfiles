#!/usr/bin/env bash
# Silent when no tether/ethernet — module disappears.
while IFS=: read -r dev type state _conn; do
  [[ "$type" == "wifi" || "$type" == "loopback" || "$type" == "bridge" || "$type" == "tun" ]] && continue
  [[ "$state" == connected* ]] || continue
  if [[ "$dev" == *u[0-9]* || "$dev" == usb* || "$dev" == rndis* ]]; then
    icon="󰀂"
  else
    icon="󰈀"
  fi
  printf '%%{T2}%s%%{T-}\n' "$icon"
  exit 0
done < <(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null)
