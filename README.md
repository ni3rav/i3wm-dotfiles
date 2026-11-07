# i3wm-dotfiles

Fedora + i3 (X11) dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## How Stow + Git work

Stow creates **symlinks** from `$HOME` into this repo. Editing a “home” path edits the file in the repo:

```text
~/.zshrc  →  ~/i3wm-dotfiles/zsh/.zshrc
~/.config/i3/config  →  ~/i3wm-dotfiles/i3/.config/i3/config
```

So normal edits are tracked by Git. Commit from this directory (`git status` / `git commit`).  
Do **not** replace a symlink with a regular file, or Stow/Git will diverge.

`extra/` and `.skills/` are **not** stowed (see `.stow-local-ignore`). Change those files only inside the repo.

Agent skill (user-invoked): `.skills/i3wm-dotfiles/` — invoke when editing packages, stowing, or restoring.

## Packages

| Package | Maps to | Notes |
|---------|---------|--------|
| `i3` | `~/.config/i3`, `~/.config/i3status` | Modular i3 + spiral (i3-layouts) |
| `vicinae` | settings.json + systemd drop-in | Drop-in adds `WantedBy=default.target` |
| `zsh` | `~/.zshrc`, `~/.zsh` | Plugins are git submodules |
| `starship` | `~/.config/starship.toml` | |
| `ghostty` | `~/.config/ghostty` | |
| `fonts` | `~/.local/share/fonts`, `~/.config/fontconfig` | JetBrainsMono NF + Plus Jakarta Sans |
| `git` | `~/.gitconfig` | |
| `code` | `~/.config/Code/User/…` | settings + keybindings only |
| `cursor` | `~/.config/Cursor/User/…` | settings + keybindings only |

## Clone

```bash
git clone --recurse-submodules <repo-url> ~/i3wm-dotfiles
cd ~/i3wm-dotfiles
```

## Stow

```bash
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor
fc-cache -fv   # after fonts
```

Dry-run: `stow -n -v --no-folding <pkg>…`  
Never `stow extra` — it is ignored on purpose.

## Fonts & keys

- **JetBrainsMono Nerd Font** — terminal, editors, i3 / i3bar
- **Plus Jakarta Sans** — default sans (browsers / UI) via fontconfig
- **Caps Lock → Escape** — `setxkbmap -option caps:escape` (i3 autostart)

## Submodules

```bash
git submodule update --init --recursive
```

## Notes

- Vicinae: stow then `systemctl --user enable --now vicinae.service` (drop-in → `default.target`; do not `disable` stowed unit symlinks)
- Spiral: `pip install --user i3-layouts`
- Fresh install: `bash extra/restore-fedora.sh` (edits dnf.conf, installs toolchain, stows)
