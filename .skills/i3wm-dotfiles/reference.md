# Package reference

## Stow package map

| Package | Home targets | Notes |
|---------|--------------|--------|
| `i3` | `~/.config/i3`, `~/.config/i3status` | Modular `config` + `config.d/*`; spiral via i3-layouts |
| `vicinae` | `settings.json` + `systemd/user/vicinae.service.d/` | Leave other Vicinae state alone |
| `zsh` | `~/.zshrc`, `~/.zsh` | Single SSOT `.zshrc`; plugins are submodules |
| `starship` | `~/.config/starship.toml` | Installed via COPR `atim/starship` |
| `ghostty` | `~/.config/ghostty` | Font: JetBrainsMono Nerd Font |
| `fonts` | `~/.local/share/fonts`, `~/.config/fontconfig` | JetBrainsMono NF + Plus Jakarta Sans |
| `git` | `~/.gitconfig` | |
| `code` | `~/.config/Code/User/{settings,keybindings}.json` | `.gitignore` limits tracked files |
| `cursor` | `~/.config/Cursor/User/{settings,keybindings}.json` | Same pattern as `code` |

## i3 layout

- Main: `i3/.config/i3/config` includes `config.d/*.conf`.
- Vars / global font: `00-variables.conf` — `font pango:JetBrainsMono Nerd Font 10`.
- Keybindings: `20-keybindings.conf` — Vicinae deeplinks; dmenu uses JetBrainsMono.
- Bar: `60-bar.conf` — same font; `i3bar-workspaces.sh` keeps empty WS visible.
- Spiral: `i3-layouts` (`$i3l` / pip `--user`); do not hand-roll tree layouts.
- Caps→Esc: `setxkbmap -option caps:escape` on autostart.

## Vicinae

- Settings SSOT: `vicinae/.config/vicinae/settings.json` only (no custom themes).
- Theme: built-in `tokyo-night`; font: JetBrainsMono Nerd Font; `compact_mode` **off** (X11 black pane otherwise); CSD off; opacity/blur in `launcher_window` (real blur needs a compositor on i3).
- i3: `for_window [class="vicinae"]` floats/centers.
- Global binds live in **i3** via `vicinae://…` deeplinks (X11 reliability), not only Vicinae’s own grabs.
- Service: stock unit is `WantedBy=graphical-session.target` (never reached under LightDM+i3 without uwsm). Stowed drop-in `vicinae.service.d/i3-session.conf` adds `WantedBy=default.target`. After stow: `systemctl --user daemon-reload && systemctl --user enable --now vicinae.service`. Never `systemctl disable` a stowed unit symlink (systemd may delete it).

## Fonts / fontconfig

- Files under `fonts/.local/share/fonts/{j,n,p}/`.
- `fonts/.config/fontconfig/fonts.conf`: monospace → JetBrainsMono NF; sans → Plus Jakarta Sans.
- After changes: `stow fonts` then `fc-cache -fv`. Verify: `fc-list : family | grep -i jetbrains`.

## zsh/.zshrc shape

Expected sections (keep this shape; do not split into `.zshrc.local`):

1. `compinit`
2. PATH SSOT: `~/.local/bin`, `~/.cargo/bin`, `~/.bun/bin`, `~/.opencode/bin`, `~/.cursor/bin`, optional `~/.cargo/env`
3. History + zoxide + aliases
4. Lazy `nvm` + default node bin on PATH
5. Bun + pnpm (`PNPM_HOME/bin`)
6. `starship init`
7. Plugins via `zsh-vi-mode` then syntax-highlighting / autosuggestions in `zvm_after_init_commands`

## extra/ (not a package)

| File | Purpose |
|------|---------|
| `restore-fedora.sh` | Full Fedora + i3 bootstrap |
| `firefox_user.js` | Manual Firefox prefs |
| `themes/` | Optional theme packs |

## Stow ignore (never home-link)

From `.stow-local-ignore`: `.git*`, `.github`, `.cursor`, `.skills`, `extra/`, README/LICENSE/md, editor junk.

## Standard stow command

```bash
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor
```
