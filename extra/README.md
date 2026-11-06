# extra (not a Stow package)

| Path | Purpose |
|------|---------|
| `restore-fedora.sh` | Fresh Fedora + i3wm bootstrap |
| `firefox_user.js` | Firefox prefs; apply manually to a profile |
| `themes/` | Optional theme packs |

```bash
bash ~/i3wm-dotfiles/extra/restore-fedora.sh
```

Interactive shell PATH lives only in the stowed `zsh/.zshrc` (single source of truth). The restore script does not write `.zshrc.local`.
