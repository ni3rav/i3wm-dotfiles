#!/usr/bin/env bash
# Compact floating control panels. WiFi/BT/brightness/volume/performance → look-applet.
set -euo pipefail

APPLET=(python3 "$HOME/.config/i3/applets/look-applet.py")

case "${1:-}" in
  brightness|display) exec "${APPLET[@]}" brightness ;;
  performance) exec "${APPLET[@]}" performance ;;
  volume) exec "${APPLET[@]}" volume ;;
  network) exec "${APPLET[@]}" network ;;
  bluetooth) exec "${APPLET[@]}" bluetooth ;;
  media) exec ~/.config/polybar/media-panel.sh ;;
  battery|power) exec gnome-control-center power ;;
  monitor) exec gnome-system-monitor ;;
  settings) exec gnome-control-center ;;
  *) exit 1 ;;
esac
