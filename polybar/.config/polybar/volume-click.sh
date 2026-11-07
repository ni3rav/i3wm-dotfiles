#!/usr/bin/env bash
# Debounce: double-click mutes; single-click opens mixer after a short wait.
flag="${XDG_RUNTIME_DIR:-/tmp}/polybar-volume-dbl.$UID"

case "${1:-}" in
  single)
    rm -f "$flag"
    sleep 0.28
    [[ -f "$flag" ]] && { rm -f "$flag"; exit 0; }
    exec ~/.config/polybar/panel.sh volume
    ;;
  double)
    : >"$flag"
    exec ~/.config/polybar/volume.sh mute
    ;;
  *) exit 1 ;;
esac
