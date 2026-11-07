# Package reference

| Package | Home targets | Notes |
|---------|--------------|--------|
| `i3` | `~/.config/i3`, `~/.config/i3status` | `config` + `config.d/*`; spiral via i3-layouts |
| `vicinae` | `settings.json` + `systemd/user/vicinae.service.d/` | Leave other Vicinae state alone |
| `zsh` | `~/.zshrc`, `~/.zsh` | One `.zshrc`; plugins are submodules |
| `starship` | `~/.config/starship.toml` | COPR `atim/starship` |
| `ghostty` | `~/.config/ghostty` | |
| `fonts` | fonts + fontconfig | JetBrainsMono NF + Plus Jakarta Sans |
| `git` | `~/.gitconfig` | |
| `code` | Code User settings/keybindings | |
| `cursor` | Cursor User settings/keybindings | |

## i3

- Includes: `config.d/*.conf`; `$i3l spiral` stays in main `config` (i3-layouts can't see includes).
- Font: JetBrainsMono Nerd Font. Caps→Esc on autostart.
- Vicinae: deeplinks in keybindings; `for_window [class="vicinae"]` floats/centers.

## Vicinae

- SSOT: `settings.json` only. Theme `tokyo-night`, JetBrainsMono, CSD off, `compact_mode` off.
- Drop-in sets `WantedBy=default.target` (stock `graphical-session.target` never starts under LightDM+i3).
- After stow: `systemctl --user daemon-reload && systemctl --user enable --now vicinae.service`. Don't `systemctl disable` a stowed unit symlink.

## zsh/.zshrc

PATH only here (no `.zshrc.local`): `~/.local/bin`, cargo, bun, opencode, cursor, nvm default node, pnpm. Then history/zoxide/aliases, lazy nvm, starship, plugins via `zvm_after_init_commands`.

## Stow

```bash
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor
```

Never stow `extra/`, `.skills/`, `.git`, `.cursor`. Restore: `bash extra/restore-fedora.sh`.
