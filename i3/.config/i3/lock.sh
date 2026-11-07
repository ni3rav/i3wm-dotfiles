#!/usr/bin/env bash
# Lock via LightDM greeter (password field). Wallpaper comes from apply-look symlink.

set -euo pipefail

I3CFG="${XDG_CONFIG_HOME:-$HOME/.config}/i3"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/i3-lock"
WALLPAPER="$I3CFG/wallpaper"

if command -v light-locker-command >/dev/null && pgrep -x light-locker >/dev/null; then
  exec light-locker-command -l
fi

if command -v dm-tool >/dev/null; then
  exec dm-tool lock
fi

# Fallback — i3lock-color (uses wallpaper symlink + cache from apply-look)
IMG="$CACHE/lock.png"
BG="1a1b26"
FG="c0caf5"
ACCENT="7aa2f7"
MUTED="565f89"
WRONG="f7768e"

if [[ -L "$WALLPAPER" || -f "$WALLPAPER" ]] && command -v magick >/dev/null; then
  mkdir -p "$CACHE"
  geom=$(xrandr 2>/dev/null | awk '/\*/ {print $1; exit}')
  [[ -z "$geom" ]] && geom=$(xrandr 2>/dev/null | awk '/ primary / {print $4; exit}' | cut -d+ -f1)
  geom=${geom:-1920x1080}
  magick "$WALLPAPER" -resize "${geom}^" -gravity center -extent "$geom" \
    -blur 0x8 -fill "#$BG" -colorize 30% "$IMG"
fi

args=(
  --nofork --ignore-empty-password --force-clock --indicator
  --radius=110 --ring-width=6 --clock
  --time-str="%H:%M" --date-str="%a, %b %d"
  --greeter-text="Enter password" --verif-text="Checking…" --wrong-text="Wrong" --noinput-text=""
  --time-font="JetBrainsMono Nerd Font" --date-font="JetBrainsMono Nerd Font"
  --greeter-font="JetBrainsMono Nerd Font" --verif-font="JetBrainsMono Nerd Font" --wrong-font="JetBrainsMono Nerd Font"
  --time-size=42 --date-size=16 --greeter-size=18 --verif-size=16 --wrong-size=16
  --inside-color="${BG}cc" --insidever-color="${BG}cc" --insidewrong-color="${BG}cc"
  --ring-color="${MUTED}ff" --ringver-color="${ACCENT}ff" --ringwrong-color="${WRONG}ff"
  --line-color="${BG}00" --keyhl-color="${ACCENT}ff" --bshl-color="${WRONG}ff" --separator-color="${BG}00"
  --verif-color="${FG}ff" --wrong-color="${WRONG}ff" --time-color="${FG}ff"
  --date-color="${MUTED}ff" --greeter-color="${FG}ff" --layout-color="${MUTED}ff"
)
[[ -f "$IMG" ]] && args+=(-i "$IMG") || args+=(-c "$BG")
exec i3lock "${args[@]}"
