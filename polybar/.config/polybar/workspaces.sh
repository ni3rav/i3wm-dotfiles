#!/usr/bin/env bash
# Always render workspaces 1–6 (i3 destroys empty ones).
# Only active/urgent get a colored pill; empty/occupied use bar bg.

ws_json=$(i3-msg -t get_workspaces 2>/dev/null) || ws_json='[]'

focused=$(jq -r '.[] | select(.focused==true) | .name' <<<"$ws_json" | head -1)
urgent=$(jq -r '.[] | select(.urgent==true) | .name' <<<"$ws_json")
occupied=$(jq -r '.[].name' <<<"$ws_json")

out=""
for i in 1 2 3 4 5 6; do
  if [[ "$focused" == "$i" ]]; then
    out+="%{A1:i3-msg workspace number $i:}%{B#7aa2f7}%{F#1a1b26}%{O10}$i%{O10}%{F-}%{B-}%{A}"
  elif grep -qx "$i" <<<"$urgent"; then
    out+="%{A1:i3-msg workspace number $i:}%{B#f7768e}%{F#1a1b26}%{O10}$i%{O10}%{F-}%{B-}%{A}"
  elif grep -qx "$i" <<<"$occupied"; then
    out+="%{A1:i3-msg workspace number $i:}%{F#7dcfff}%{O10}$i%{O10}%{F-}%{A}"
  else
    out+="%{A1:i3-msg workspace number $i:}%{F#a9b1d6}%{O10}$i%{O10}%{F-}%{A}"
  fi
done

printf '%s\n' "$out"
