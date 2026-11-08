# Package reference

| Package | Home targets | Notes |
|---------|--------------|--------|
| `i3` | `~/.config/i3` | polybar replaces i3bar/i3status; lock via light-locker |
| `vicinae` | `settings.json` + `systemd/user/vicinae.service.d/` | Leave other Vicinae state alone |
| `zsh` | `~/.zshrc`, `~/.zsh` | One `.zshrc`; plugins are submodules |
| `starship` | `~/.config/starship.toml` | COPR `atim/starship` |
| `ghostty` | `~/.config/ghostty/config.ghostty` | |
| `fonts` | fonts + fontconfig | JetBrainsMono NF + Plus Jakarta Sans |
| `git` | `~/.gitconfig` | |
| `code` | Code User settings/keybindings | |
| `cursor` | Cursor User settings/keybindings | |
| `xdg` | `~/.config/mimeapps.list` | Text/config → GNOME Text Editor; nm/blueman tray Hidden |
| `picom` | `~/.config/picom/picom.conf` | X11 compositor |
| `polybar` | `~/.config/polybar/` | Top bar + tray; `launch.sh` from i3 `exec_always` |
| `dunst` | `~/.config/dunst/` | Colors from apply-look |
| `flameshot` | `~/.config/flameshot/` | Print Screen |

## i3

- `$i3l spiral` stays in main `config` (i3-layouts can't see includes).
- Gaps + `client.focused` accent `#7aa2f7`. No `bar {}` — Polybar owns the top strip.
- Media OSD: `osd.sh` → `osd-hud.py` (brightness + volume). `brightnessctl`, `pactl`, `python3-gobject`, JetBrainsMono NF. Volume may show >100%; bar caps at full.
- Bar applets: `panel.sh` → `applets/look-applet.py` — `network` `bluetooth` `brightness` `volume` `performance`. Top-right; Escape/re-click closes. Wi‑Fi: share expander (password + QR via `qrencode`). Brightness: night light (`redshift`). Advanced: nm-connection-editor / blueman-manager / pavucontrol.
- Flatpak look: `apply-look.sh` **copies** the GTK theme into `~/.local/share/themes/` (sandbox cannot follow stow/repo symlinks), writes the full theme into `~/.config/gtk-{3,4}.0/gtk.css` (libadwaita user stylesheet), real `settings.ini`, and Flatpak overrides (`GTK_THEME`, `ICON_THEME`, `ADW_DISABLE_PORTAL=1`, `ADW_DEBUG_COLOR_SCHEME=prefer-dark`).
- Portals on i3: stowed `~/.config/systemd/user/xdg-desktop-portal.service` drops `Requisite=graphical-session.target` (never reached under LightDM/i3).

## Restore packages (highlights)

Core: `i3`, `polybar`, `dunst`, `flameshot`, `brightnessctl`, `pulseaudio-utils`, `python3-gobject`, `qrencode`, `redshift`, `blueman`, `pavucontrol`, `nm-connection-editor`, `gnome-clocks`, `snapshot`, …  
Flatpak: OBS, OnlyOffice, Resources.

## Vicinae

- SSOT: `settings.json`. Theme `tokyo-night`, JetBrainsMono, CSD off, `compact_mode` off.
- Drop-in `WantedBy=default.target`. After stow: `systemctl --user enable --now vicinae.service`.

## Stow

```bash
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor xdg picom polybar dunst flameshot
```

Never stow `extra/`, `.skills/`, `.git`, `.cursor`. Restore: `bash extra/restore-fedora.sh`.
