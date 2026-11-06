# i3wm-dotfiles

Fedora + i3 (X11) dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package   | Symlinks into | Notes |
|-----------|---------------|--------|
| `i3`      | `~/.config/i3`, `~/.config/i3status` | Modular i3 config, bar, helper scripts |
| `vicinae` | `~/.config/vicinae/settings.json` only | Does **not** replace the whole Vicinae directory |

## Stow

```bash
cd ~/i3wm-dotfiles
stow -v --no-folding i3
mkdir -p ~/.config/vicinae          # keep a real directory for Vicinae data
stow -v --no-folding vicinae
```

Dry-run: `stow -n -v --no-folding i3 vicinae`

## Stack

- **i3** — window manager (modular `config.d/`)
- **i3-layouts** — spiral tiling (`pip install --user i3-layouts`)
- **Vicinae** — launcher / clipboard / files / emoji / window switcher (systemd user unit `vicinae.service`)
- **Ghostty**, **Nautilus**, **Firefox**, **i3status**

Enable Vicinae: `systemctl --user enable --now vicinae.service`

Validate i3: `i3 -C`
