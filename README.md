# i3wm-dotfiles

Fedora + i3 (X11), managed with GNU Stow (`stow -v --no-folding …` from this repo).

Home paths are symlinks into this tree — edit here, then commit. Don’t replace a symlink with a regular file.

`extra/` and `.skills/` are not stowed.

| Package | Maps to |
|---------|---------|
| `i3` | `~/.config/i3` — polybar (not i3bar); `osd.sh` brightness/volume HUD; `applets/look-applet.py` bar popups |
| `vicinae` | `settings.json` + systemd drop-in |
| `zsh` | `~/.zshrc`, `~/.zsh` |
| `starship` | `~/.config/starship.toml` |
| `ghostty` | `~/.config/ghostty/config.ghostty` |
| `fonts` | fonts + fontconfig |
| `git` | `~/.gitconfig` |
| `code` | VS Code user settings/keybindings |
| `cursor` | Cursor user settings/keybindings |
| `xdg` | `mimeapps.list` + gtk/env |
| `picom` | `~/.config/picom/picom.conf` |
| `polybar` | `~/.config/polybar/` |
| `dunst` | `~/.config/dunst/` (colors via apply-look) |
| `flameshot` | Print Screen + legacy X11 |

## Look / media

- `~/.config/i3/apply-look.sh` + `look.conf` → GTK/icons/wallpaper, dunst colors, Flatpak theme (materializes theme into `~/.local/share/themes` so sandboxes don’t follow stow symlinks; `GTK_THEME` / `ICON_THEME` / `ADW_DISABLE_PORTAL`).
- OSD: media keys → `osd.sh` → `osd-hud.py` (brightness + volume; volume may show >100%, bar caps at 100%).
- Bar applets (top-right): Wi‑Fi, Bluetooth, brightness (+ night light), volume, performance. Wi‑Fi share expander shows password + QR.
- Needs: `brightnessctl`, `pulseaudio-utils`, `python3-gobject`, `qrencode`, `redshift`, JetBrainsMono NF.

```bash
git clone --recurse-submodules <repo-url> ~/i3wm-dotfiles
cd ~/i3wm-dotfiles
git submodule update --init --recursive
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor xdg picom polybar dunst flameshot
fc-cache -fv
systemctl --user enable --now vicinae.service
```

Fresh machine: `bash extra/restore-fedora.sh`
