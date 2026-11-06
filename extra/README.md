# extra (not a Stow package)

Manual restore helpers and theme packs. Ignored by Stow via `.stow-local-ignore`.

| Path | Purpose |
|------|---------|
| `scripts/restore-fedora.sh` | Fresh Fedora bootstrap (installs packages — run deliberately) |
| `scripts/shepherd.sh` | Theme pack apply/create (expects `extra/themes/`) |
| `themes/` | Theme packs consumed by shepherd |

The Stow package `restore-fedora` still installs the same tools into `~/.local/bin` when stowed.
