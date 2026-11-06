# extra (not a Stow package)

Manual extras kept in-repo only. Ignored by Stow via `.stow-local-ignore`.

| Path | Purpose |
|------|---------|
| `restore-fedora.sh` | Fresh Fedora + i3wm bootstrap (DNF config, packages, PATH, stow) |
| `firefox_user.js` | Firefox prefs (arkenfox-style); apply manually to a profile |
| `themes/` | Optional theme packs |

## Restore

```bash
bash ~/i3wm-dotfiles/extra/restore-fedora.sh
```

The script:

1. Writes `/etc/dnf/dnf.conf` (parallel downloads / fastestmirror)
2. Runs `dnf upgrade`
3. Installs core tools **without** pulling `starship` from base repos (uses COPR for starship)
4. Installs Go, Rust, Helium, Charm, Bun, NVM/Node/pnpm, uv, OpenCode, VS Code, Cursor CLI
5. Flatpak: OBS + OnlyOffice
6. Ghostty, Vicinae, i3-layouts (needed by these configs)
7. `git submodule update`, `stow`, `fc-cache`
8. Ensures cargo / bun / uv / opencode / cursor bins are on PATH for the install session and via `~/.zshrc` + `~/.zshrc.local`
