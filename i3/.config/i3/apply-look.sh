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
GTK_THEME=${GTK_THEME%:dark} # never store :dark in theme name
GTK_THEME_ENV="${GTK_THEME}:dark"
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

# Libadwaita ignores gtk-theme-name. Symlink the theme into ~/.config/gtk-N.0
# (relative @import) so Nautilus / Text Editor load Tokyo Night named colors.
force_gtk_dark_css() {
  local ver=$1
  local dest="$HOME/.config/gtk-${ver}.0"
  local theme_dir="$HOME/.themes/$GTK_THEME/gtk-${ver}.0"
  local dark_css="$theme_dir/gtk-dark.css"
  [[ -f "$dark_css" ]] || dark_css="$theme_dir/gtk.css"
  [[ -f "$dark_css" ]] || return 0
  mkdir -p "$dest"
  ln -sfn "$dark_css" "$dest/gtk-dark.css"
  [[ -f "$theme_dir/gtk.css" ]] && ln -sfn "$theme_dir/gtk.css" "$dest/gtk-theme.css"
  if [[ -d "$theme_dir/assets" ]]; then
    ln -sfn "$theme_dir/assets" "$dest/assets"
  fi
  local css_body
  css_body=$(cat <<'EOF'
/* Applied by apply-look.sh — Tokyo Night dark for libadwaita */
@import url("gtk-dark.css");

/* Square corners */
* { border-radius: 0; }
window, window.background, .csd, headerbar, .titlebar, toast, popover,
popover > contents, menu, .menu, dialog, messagedialog, sheet, .background,
.card, .osd { border-radius: 0; }
EOF
)
  rm -f "$dest/gtk.css"
  printf '%s\n' "$css_body" >"$dest/gtk.css"
  local repo_dest="$REPO/xdg/.config/gtk-${ver}.0"
  if [[ -d "$repo_dest" ]]; then
    printf '%s\n' "$css_body" >"$repo_dest/gtk.css"
  fi
}
force_gtk_dark_css 3
force_gtk_dark_css 4

# Keep stowed + live settings.ini in sync (name never includes :dark)
for d in \
  "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" \
  "$REPO/xdg/.config/gtk-3.0" "$REPO/xdg/.config/gtk-4.0"
do
  [[ -d "$d" ]] || continue
  write_gtk_settings "$d"
done

# Session env (login via .xprofile; systemd/user via environment.d + import)
mkdir -p "$HOME/.config/environment.d" "$I3CFG"
cat >"$I3CFG/look.env" <<EOF
GTK_THEME=$GTK_THEME_ENV
GTK2_RC_FILES=$HOME/.gtkrc-2.0
ADW_DISABLE_PORTAL=1
EOF
cp "$I3CFG/look.env" "$HOME/.config/environment.d/90-look.conf"
# Do not mutate GTK_THEME shell var used by gsettings below
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
export ADW_DISABLE_PORTAL=1
if command -v systemctl >/dev/null; then
  systemctl --user set-environment "GTK_THEME=$GTK_THEME_ENV" "GTK2_RC_FILES=$HOME/.gtkrc-2.0" ADW_DISABLE_PORTAL=1 2>/dev/null || true
fi
if command -v dbus-update-activation-environment >/dev/null; then
  env GTK_THEME="$GTK_THEME_ENV" GTK2_RC_FILES="$HOME/.gtkrc-2.0" ADW_DISABLE_PORTAL=1 \
    dbus-update-activation-environment --systemd GTK_THEME GTK2_RC_FILES ADW_DISABLE_PORTAL 2>/dev/null || true
fi

cat >"$HOME/.icons/default/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=$CURSOR_THEME
EOF

# Expose active icon theme to GTK2 paths (name from look.conf only)
mkdir -p "$HOME/.local/share/icons" "$HOME/.icons"
for name in "$ICON_THEME"; do
  src=""
  [[ -d "$HOME/.local/share/icons/$name" ]] && src="$HOME/.local/share/icons/$name"
  [[ -z "$src" && -d "/usr/share/icons/$name" ]] && src="/usr/share/icons/$name"
  [[ -n "$src" ]] || continue
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

# Colors from the active GTK theme CSS (look.conf gtk_theme) — never bake a palette in
gtk_define_color() {
  local name=$1 css=$2
  [[ -f "$css" ]] || return 1
  local hex
  hex=$(grep -E "^@define-color ${name} #" "$css" 2>/dev/null | awk '{print $3; exit}')
  hex=${hex%;} # CSS trailing ;
  [[ "$hex" == \#* && ${#hex} -eq 7 ]] || return 1
  printf '%s' "$hex"
}

# Dunst: structure in stowed dunstrc; colors/icons in drop-in from GTK theme + look.conf
sync_dunst_look() {
  local css="" c_bg c_fg c_frame c_crit
  for candidate in \
    "$HOME/.themes/$GTK_THEME/gtk-4.0/gtk-dark.css" \
    "$HOME/.themes/$GTK_THEME/gtk-4.0/gtk.css" \
    "$HOME/.themes/$GTK_THEME/gtk-3.0/gtk-dark.css" \
    "$HOME/.themes/$GTK_THEME/gtk-3.0/gtk.css"
  do
    [[ -f "$candidate" ]] && { css=$candidate; break; }
  done
  [[ -n "$css" ]] || { echo "warn: no GTK CSS for dunst colors ($GTK_THEME)" >&2; return 0; }

  c_bg=$(gtk_define_color window_bg_color "$css" || true)
  c_fg=$(gtk_define_color window_fg_color "$css" || true)
  c_frame=$(gtk_define_color accent_bg_color "$css" || gtk_define_color accent_color "$css" || true)
  c_crit=$(gtk_define_color error_color "$css" || gtk_define_color destructive_bg_color "$css" || true)
  [[ -n "$c_bg" && -n "$c_fg" && -n "$c_frame" ]] || {
    echo "warn: incomplete theme colors for dunst (css=$css)" >&2
    return 0
  }
  c_crit=${c_crit:-$c_frame}

  mkdir -p "$HOME/.config/dunst/dunstrc.d"
  cat >"$HOME/.config/dunst/dunstrc.d/90-look.conf" <<EOF
# Generated by apply-look.sh from $GTK_THEME — do not edit; change look.conf + re-run
[global]
    frame_color = "$c_frame"
    highlight = "$c_frame"
    icon_theme = $ICON_THEME

[urgency_low]
    background = "$c_bg"
    foreground = "$c_fg"
    frame_color = "$c_frame"

[urgency_normal]
    background = "$c_bg"
    foreground = "$c_fg"
    frame_color = "$c_frame"

[urgency_critical]
    background = "$c_bg"
    foreground = "$c_fg"
    frame_color = "$c_crit"
EOF

  # Keep lock dim color in sync with theme bg when we rewrite the cache below
  LOOK_BG=$c_bg

  # Restart so drop-in is picked up (USR1/USR2 are pause/unpause only)
  if pgrep -x dunst >/dev/null; then
    killall -q dunst 2>/dev/null || true
    sleep 0.1
    dunst >/dev/null 2>&1 &
  fi
  echo "dunst look → bg=$c_bg fg=$c_fg frame=$c_frame icons=$ICON_THEME"
}
LOOK_BG=""
sync_dunst_look

# Flatpak: expose host themes/icons/gtk config + look env (no per-app wrappers)
sync_flatpak_look() {
  command -v flatpak >/dev/null || return 0
  mkdir -p "$HOME/.local/share/themes"
  if [[ -e "$HOME/.themes/$GTK_THEME" ]]; then
    ln -sfn "$HOME/.themes/$GTK_THEME" "$HOME/.local/share/themes/$GTK_THEME"
  fi
  # Global user override — every Flatpak sees the same look as host GTK
  flatpak override --user \
    --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=xdg-data/themes:ro \
    --filesystem=xdg-data/icons:ro \
    --filesystem="$HOME/.themes:ro" \
    --filesystem="$HOME/.icons:ro" \
    --env=GTK_THEME="$GTK_THEME_ENV" \
    --env=ADW_DISABLE_PORTAL=1 \
    --env=XCURSOR_THEME="$CURSOR_THEME" \
    --env=XCURSOR_SIZE="$CURSOR_SIZE" \
    2>/dev/null || true
  echo "flatpak look → gtk=$GTK_THEME_ENV icons=$ICON_THEME cursor=$CURSOR_THEME"
}
sync_flatpak_look

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
    -blur 0x8 -fill "${LOOK_BG:-#000000}" -colorize 30% "$CACHE/lock.png" || true
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
