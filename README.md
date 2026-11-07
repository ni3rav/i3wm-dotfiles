# i3wm-dotfiles

Fedora + i3 (X11), managed with GNU Stow (`stow -v --no-folding …` from this repo).

Home paths are symlinks into this tree — edit here, then commit. Don’t replace a symlink with a regular file.

`extra/` and `.skills/` are not stowed.

| Package | Maps to |
|---------|---------|
| `i3` | `~/.config/i3`, `~/.config/i3status` |
| `vicinae` | `settings.json` + systemd drop-in |
| `zsh` | `~/.zshrc`, `~/.zsh` |
| `starship` | `~/.config/starship.toml` |
| `ghostty` | `~/.config/ghostty/config.ghostty` |
| `fonts` | fonts + fontconfig |
| `git` | `~/.gitconfig` |
| `code` | VS Code user settings/keybindings |
| `cursor` | Cursor user settings/keybindings |
| `xdg` | `mimeapps.list` |
| `picom` | `~/.config/picom/picom.conf` |
| `polybar` | `~/.config/polybar/` |

```bash
git clone --recurse-submodules <repo-url> ~/i3wm-dotfiles
cd ~/i3wm-dotfiles
git submodule update --init --recursive
mkdir -p ~/.config/vicinae
stow -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor xdg picom polybar
fc-cache -fv
systemctl --user enable --now vicinae.service
```

Fresh machine: `bash extra/restore-fedora.sh`
