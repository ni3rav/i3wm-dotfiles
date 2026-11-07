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
| `xdg` | `~/.config/mimeapps.list` | Text/config → GNOME Text Editor |
| `picom` | `~/.config/picom/picom.conf` | X11 compositor |
| `polybar` | `~/.config/polybar/` | Top bar + tray; `launch.sh` from i3 `exec_always` |

## i3

- `$i3l spiral` stays in main `config` (i3-layouts can't see includes).
- Gaps + `client.focused` accent `#7aa2f7`. No `bar {}` — Polybar owns the top strip.
- Tray apps: `nm-applet`, `blueman-applet`.

## Vicinae

- SSOT: `settings.json`. Theme `tokyo-night`, JetBrainsMono, CSD off, `compact_mode` off.
- Drop-in `WantedBy=default.target`. After stow: `systemctl --user enable --now vicinae.service`.

## Stow

```bash
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor xdg picom polybar
```

Never stow `extra/`, `.skills/`, `.git`, `.cursor`. Restore: `bash extra/restore-fedora.sh`.
