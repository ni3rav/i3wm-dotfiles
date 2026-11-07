# Workflows

## Edit a package

1. Edit under `~/i3wm-dotfiles/<pkg>/…`
2. `stow -n -v --no-folding <pkg>` then `stow -v --no-folding <pkg>` if needed
3. Reload (i3 / vicinae / shell / `fc-cache`)
4. Commit only if asked

## Add a package

Mirror `$HOME` under a new top-level dir, stow it, update README + `step_dotfiles` stow list + `reference.md`. Non-stowed stuff goes in `extra/` or `.stow-local-ignore`.

## Clobbered ~/.zshrc

```bash
rm -f ~/.zshrc.local
[[ -f ~/.zshrc && ! -L ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.installer-clobber
cd ~/i3wm-dotfiles && stow -v --no-folding zsh
```

## Clobbered vicinae settings.json

```bash
mv ~/.config/vicinae/settings.json ~/.config/vicinae/settings.json.pre-stow
cd ~/i3wm-dotfiles && stow -v --no-folding vicinae
```

## Restore / validate

```bash
bash ~/i3wm-dotfiles/extra/restore-fedora.sh
cd ~/i3wm-dotfiles
stow -n -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor xdg picom
i3 -C -c ~/.config/i3/config
readlink -f ~/.zshrc
test ! -e ~/.zshrc.local
```
