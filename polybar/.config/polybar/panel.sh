#!/usr/bin/env bash
# Compact floating control panels (i3 floats Yad / app windows).

brightness_panel() {
  local cur max pct val
  cur=$(brightnessctl g)
  max=$(brightnessctl m)
  pct=$((cur * 100 / max))
  val=$(yad --scale \
    --title="Brightness" \
    --text="Display brightness" \
    --min-value=1 --max-value=100 --value="$pct" \
    --step=1 --print-partial --width=360 --height=120 \
    --button="OK:0" --button="Cancel:1" \
    --on-top --center 2>/dev/null) || return 0
  [[ -n "$val" ]] || return 0
  brightnessctl set "${val}%" >/dev/null
}

performance_panel() {
  local current choice next
  current=$(powerprofilesctl get 2>/dev/null || echo balanced)
  choice=$(yad --list --radiolist \
    --title="Performance" \
    --text="Power profile" \
    --column="Pick" --column="Profile" --column="Id" \
    --hide-column=3 --print-column=3 \
    --width=360 --height=220 --on-top --center \
    --button="OK:0" --button="Cancel:1" \
    $([ "$current" = power-saver ] && echo TRUE || echo FALSE) "Power saver" "power-saver" \
    $([ "$current" = balanced ] && echo TRUE || echo FALSE) "Balanced" "balanced" \
    $([ "$current" = performance ] && echo TRUE || echo FALSE) "Performance" "performance" \
    2>/dev/null) || return 0
  next=${choice%%|}
  next=${next//$'\n'/}
  [[ -n "$next" ]] || return 0
  powerprofilesctl set "$next" >/dev/null 2>&1 || true
}

case "${1:-}" in
  brightness) brightness_panel ;;
  performance) performance_panel ;;
  volume) exec pavucontrol ;;
  network) exec nm-connection-editor ;;
  bluetooth) exec blueman-manager ;;
  battery|power) exec gnome-control-center power ;;
  display) brightness_panel ;;
  monitor) exec gnome-system-monitor ;;
  settings) exec gnome-control-center ;;
  *) exit 1 ;;
esac
