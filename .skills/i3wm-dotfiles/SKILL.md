---
name: i3wm-dotfiles
description: >-
  Maintain Fedora i3wm X11 Stow dotfiles in ~/i3wm-dotfiles: edit packages,
  add packages, restow, keep a single ~/.zshrc, use extra/restore-fedora.sh.
  User-invoked when changing dotfiles, stowing, or restoring.
disable-model-invocation: true
---

# i3wm-dotfiles

Repo: `~/i3wm-dotfiles`. Stow maps packages into `$HOME`.

## Rules

1. One shell config: stowed `zsh/.zshrc` only. Never `.zshrc.local`.
2. Edit in the repo (live paths are symlinks).
3. Never stow `extra/`, `.skills/`, `.git`, `.cursor`, or docs.
4. Always `stow -v --no-folding <pkgs…>` from repo root.
5. Surgical changes only; match existing style.

Packages: `i3` `vicinae` `zsh` `starship` `ghostty` `fonts` `git` `code` `cursor` `xdg` `picom` `polybar` `dunst` `flameshot`.

See [reference.md](reference.md) and [workflows.md](workflows.md).

## After changes

```bash
cd ~/i3wm-dotfiles
stow -n -v --no-folding <pkg>…
stow -v --no-folding <pkg>…
```

Fonts → `fc-cache -fv`. i3 → `i3-msg reload`. Vicinae → `systemctl --user try-reload-or-restart vicinae.service`.

If Stow hits a real file: move aside (`*.pre-stow`), restow. Don’t `--adopt` unless asked.

Fresh install: `bash extra/restore-fedora.sh`. Commit only when asked.
