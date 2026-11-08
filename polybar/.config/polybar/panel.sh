#!/usr/bin/env bash
# Compact floating control panels → look-applet.
set -euo pipefail

# Polybar click env is PATH-thin; inherit look.env + POSIX default PATH
if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/i3/look.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${XDG_CONFIG_HOME:-$HOME/.config}/i3/look.env"
  set +a
fi
_std=$(getconf PATH 2>/dev/null || true)
[[ -n "$_std" ]] && export PATH="${PATH:+$PATH:}$_std"
unset _std

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
  *) exit 1 ;;
esac
