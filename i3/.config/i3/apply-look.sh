#!/usr/bin/env bash
# Single entry point: edit look.conf, run this. Propagates wallpaper + look everywhere.

set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/i3/look.conf"
[[ -f "$CONF" ]] || { echo "missing $CONF" >&2; exit 1; }

SCRIPT=$(readlink -f "${BASH_SOURCE[0]}")
REPO=$(cd "$(dirname "$SCRIPT")/../../.." && pwd)
I3CFG="${XDG_CONFIG_HOME:-$HOME/.config}/i3"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/i3-lock"
SYS_BG_DIR="/usr/share/backgrounds/tokyo-night"
SYS_BG="$SYS_BG_DIR/current"
SYS_GREETER="/etc/lightdm/lightdm-gtk-greeter.conf"

declare -A KV=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  key=${line%%=*}
  val=${line#*=}
  key=$(echo "$key" | xargs)
  val=$(echo "$val" | xargs)
  KV[$key]=$val
done <"$CONF"

resolve_path() {
  local p=$1
  [[ -z "$p" ]] && { echo ""; return; }
  p=${p/#\~/$HOME}
  [[ "$p" != /* ]] && p="$REPO/$p"
  readlink -f "$p" 2>/dev/null || echo "$p"
}

WALLPAPER=$(resolve_path "${KV[wallpaper]:-}")
GTK_THEME=${KV[gtk_theme]:-Tokyonight-BL-LB-Dark}
ICON_THEME=${KV[icon_theme]:-Tela-circle-dark}
CURSOR_THEME=${KV[cursor_theme]:-Bibata-Modern-Classic}
CURSOR_SIZE=${KV[cursor_size]:-24}
PACK_GTK="$REPO/extra/themes/tokyo-night/gtk"

mkdir -p "$I3CFG" "$HOME/.themes" "$HOME/.icons/default" "$HOME/.config/gtk-2.0" \
  "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/environment.d" "$CACHE"

# --- canonical wallpaper symlink (everything else reads this) ---
if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
  ln -sfn "$WALLPAPER" "$I3CFG/wallpaper"
else
  echo "warn: wallpaper missing: ${KV[wallpaper]:-}" >&2
fi

# --- GTK theme: symlink into ~/.themes (no duplicate tree) ---
if [[ "$GTK_THEME" == "Tokyonight-BL-LB-Dark" && -d "$PACK_GTK" ]]; then
  rm -rf "$HOME/.themes/$GTK_THEME"
  ln -sfn "$PACK_GTK" "$HOME/.themes/$GTK_THEME"
fi

# GTK 2/3/4 + env
cat >"$HOME/.gtkrc-2.0" <<EOF
gtk-theme-name="$GTK_THEME"
gtk-icon-theme-name="$ICON_THEME"
gtk-cursor-theme-name="$CURSOR_THEME"
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=1
EOF
ln -sfn "$HOME/.gtkrc-2.0" "$HOME/.config/gtk-2.0/gtkrc"

write_gtk_settings() {
  cat >"$1/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-cursor-theme-name=$CURSOR_THEME
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=:menu
EOF
}
write_gtk_settings "$HOME/.config/gtk-3.0"
write_gtk_settings "$HOME/.config/gtk-4.0"

cat >"$HOME/.config/environment.d/90-look.conf" <<EOF
GTK_THEME=$GTK_THEME
GTK2_RC_FILES=$HOME/.gtkrc-2.0
EOF
export GTK_THEME="$GTK_THEME"
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
# Also keep xdg package settings.ini in sync when stowed
for d in "$REPO/xdg/.config/gtk-3.0" "$REPO/xdg/.config/gtk-4.0"; do
  [[ -d "$d" ]] || continue
  cat >"$d/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-cursor-theme-name=$CURSOR_THEME
gtk-cursor-theme-size=$CURSOR_SIZE
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=:menu
EOF
done

cat >"$HOME/.icons/default/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=$CURSOR_THEME
EOF

# Expose icons to GTK/Qt/XDG (same names as look.conf)
mkdir -p "$HOME/.local/share/icons" "$HOME/.icons"
for name in "$ICON_THEME" Tela-circle Tela-circle-dark Tela-circle-light; do
  src=""
  [[ -d "$HOME/.local/share/icons/$name" ]] && src="$HOME/.local/share/icons/$name"
  [[ -z "$src" && -d "/usr/share/icons/$name" ]] && src="/usr/share/icons/$name"
  [[ -n "$src" ]] || continue
  # ~/.icons symlink for older GTK2 paths
  ln -sfn "$src" "$HOME/.icons/$name"
done

if command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" || true
  gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" || true
  gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" || true
  gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" || true
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
  gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme true 2>/dev/null || true
fi

# Vicinae (GUI may replace the stow symlink — patch live file + repo copy)
sync_vicinae_icons() {
  local icon=$1
  ICON_THEME="$icon" REPO="$REPO" python3 <<'PY' || true
import json, os, re, sys
from pathlib import Path

icon = os.environ["ICON_THEME"]
repo = Path(os.environ["REPO"])
paths = [
    Path.home() / ".config/vicinae/settings.json",
    repo / "vicinae/.config/vicinae/settings.json",
]

def patch(text: str) -> str:
    # JSONC: strip // comments for parse, then dump pure JSON back for reliability
    lines = []
    for line in text.splitlines():
        if line.lstrip().startswith("//"):
            continue
        lines.append(line)
    raw = "\n".join(lines)
    raw = re.sub(r",\s*}", "}", raw)
    raw = re.sub(r",\s*]", "]", raw)
    data = json.loads(raw)
    theme = data.setdefault("theme", {})
    for mode in ("dark", "light"):
        block = theme.setdefault(mode, {})
        if isinstance(block, dict):
            block["icon_theme"] = icon
        else:
            theme[mode] = {"name": "tokyo-night" if mode == "dark" else "vicinae-light", "icon_theme": icon}
    # keep dark theme name if missing
    theme.setdefault("dark", {}).setdefault("name", "tokyo-night")
    return json.dumps(data, indent="\t") + "\n"

for path in paths:
    if not path.is_file():
        continue
    try:
        path.write_text(patch(path.read_text()))
        print(f"vicinae icons → {icon} ({path})")
    except Exception as e:
        print(f"warn: vicinae patch failed for {path}: {e}", file=sys.stderr)
PY
}
sync_vicinae_icons "$ICON_THEME"

# Desktop wallpaper
if [[ -f "$I3CFG/wallpaper" ]] && command -v feh >/dev/null; then
  feh --no-fehbg --bg-fill "$I3CFG/wallpaper"
fi

# Lock fallback image cache (light-locker uses greeter; i3lock fallback uses this)
if [[ -f "$I3CFG/wallpaper" ]] && command -v magick >/dev/null; then
  geom=$(xrandr 2>/dev/null | awk '/\*/ {print $1; exit}')
  [[ -z "$geom" ]] && geom=$(xrandr 2>/dev/null | awk '/ primary / {print $4; exit}' | cut -d+ -f1)
  geom=${geom:-1920x1080}
  magick "$I3CFG/wallpaper" -resize "${geom}^" -gravity center -extent "$geom" \
    -blur 0x8 -fill '#1a1b26' -colorize 30% "$CACHE/lock.png" || true
fi

if command -v xsetroot >/dev/null; then
  xsetroot -cursor_name left_ptr 2>/dev/null || true
fi

# --- system (LightDM): home is 700 so greeter cannot follow symlinks into ~ ---
# One file "current" under /usr/share; apply-look refreshes it when wallpaper changes.
sync_lightdm() {
  command -v sudo >/dev/null || return 0
  [[ -f "$I3CFG/wallpaper" ]] || return 0

  if ! sudo -n true 2>/dev/null; then
    if [[ -t 0 ]]; then
      sudo true || return 0
    else
      echo "note: login wallpaper needs sudo — re-run: sudo -v && $SCRIPT"
      return 0
    fi
  fi

  sudo mkdir -p "$SYS_BG_DIR" /usr/share/themes /usr/share/icons
  # Single system wallpaper file (greeter cannot read ~ — home is mode 700)
  sudo install -m 644 "$I3CFG/wallpaper" "$SYS_BG"
  # Remove old redundant greeter wallpaper name if present
  sudo rm -f "$SYS_BG_DIR/cityscape.jpg"

  # System GTK/icons: copy once (cannot symlink into ~ for lightdm)
  if [[ -d "$PACK_GTK" && ! -d /usr/share/themes/Tokyonight-BL-LB-Dark ]]; then
    sudo cp -a "$PACK_GTK" /usr/share/themes/Tokyonight-BL-LB-Dark
  fi
  for pair in \
    "Tela-circle-dark:$HOME/.local/share/icons/Tela-circle-dark" \
    "Tela-circle:$HOME/.local/share/icons/Tela-circle" \
    "Bibata-Modern-Classic:$HOME/.local/share/icons/Bibata-Modern-Classic"
  do
    name=${pair%%:*}
    src=${pair#*:}
    [[ -e "$src" ]] || continue
    [[ -e "/usr/share/icons/$name" ]] && continue
    sudo cp -a "$src" "/usr/share/icons/$name"
  done

  sudo tee "$SYS_GREETER" >/dev/null <<EOF
[greeter]
background=$SYS_BG
user-background=false
theme-name=$GTK_THEME
icon-theme-name=$ICON_THEME
cursor-theme-name=$CURSOR_THEME
cursor-theme-size=$CURSOR_SIZE
font-name=JetBrainsMono Nerd Font 11
xft-antialias=true
xft-hintstyle=slight
indicators=~host;~spacer;~clock;~spacer;~session;~power
clock-format=%a %d %b · %H:%M
position=50%,center 50%,center
EOF
}

sync_lightdm

echo "look applied → wallpaper=$(readlink -f "$I3CFG/wallpaper" 2>/dev/null || echo none) gtk=$GTK_THEME icons=$ICON_THEME cursor=$CURSOR_THEME"
echo "edit $CONF then re-run: $SCRIPT"
