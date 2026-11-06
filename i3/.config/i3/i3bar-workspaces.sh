#!/usr/bin/env bash
# Always show workspaces 1–6 in i3bar, including empty ones (i3 >= 4.23).
# Uses the i3bar workspace buttons protocol:
# https://i3wm.org/docs/i3bar-workspace-protocol.html

set -euo pipefail

emit() {
    local output
    output=$(i3-msg -t get_outputs | jq -r \
        '([.[] | select(.primary == true)][0].name)
         // ([.[] | select(.active == true)][0].name)
         // "eDP-1"')

    i3-msg -t get_workspaces | jq -c --arg out "$output" '
        def fake($n):
            { num: ($n|tonumber), name: $n, visible: false, focused: false,
              urgent: false, output: $out };
        . as $ws
        | ["1","2","3","4","5","6"]
        | map(. as $n | ($ws[] | select(.name == $n)) // fake($n))
    '
}

# Initial dump so the bar is not empty at startup
emit

i3-msg -t subscribe -m '["workspace", "output"]' | while read -r _; do
    emit
done
