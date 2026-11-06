---
name: i3wm-dotfiles
description: >-
  Maintain Fedora i3wm X11 Stow dotfiles in ~/i3wm-dotfiles: edit packages,
  add new Stow packages, restow safely, keep a single ~/.zshrc SSOT, and use
  extra/restore-fedora.sh. User-invoked when changing dotfiles, stowing, or
  restoring this desktop setup.
disable-model-invocation: true
---

# i3wm-dotfiles

Repo root: `~/i3wm-dotfiles` (this tree). GNU Stow maps package trees into `$HOME`.

## Non-negotiables

1. **One interactive shell config**: stowed `zsh/.zshrc` → `~/.zshrc` only. Never create `.zshrc.local`. Guard against installers that append to or replace `~/.zshrc`.
2. **Edit in the repo, not copies under `$HOME`**. Live paths are symlinks into this repo.
3. **Never stow** `extra/`, `.skills/`, `.git`, `.cursor`, or docs. See `.stow-local-ignore`.
4. **Always** `stow -v --no-folding <pkgs…>` from the repo root (no directory folding).
5. **Surgical changes**: touch only what the user asked for; match existing package style.

## Quick orientation

| Path | Role |
|------|------|
| `<pkg>/…` | Stow package (mirrors `$HOME` layout under the package dir) |
| `extra/` | Not stowed — `restore-fedora.sh`, `firefox_user.js`, themes |
| `.skills/` | Not stowed — agent skills for this repo |
| `.stow-local-ignore` | Repo-level ignore for Stow |

Stow packages today: `i3` `vicinae` `zsh` `starship` `ghostty` `fonts` `git` `code` `cursor`.

Read [reference.md](reference.md) for package details. Read [workflows.md](workflows.md) before adding a package or running restore.

## Before any change

1. Confirm cwd / `DOTFILES_DIR` is `~/i3wm-dotfiles`.
2. `git status` — know what is already dirty.
3. If editing a live path, verify it is a symlink into this repo (`readlink -f …`).
4. Prefer editing the file under the package tree (e.g. `i3/.config/i3/…`).

## After any Stow-affecting change

```bash
cd ~/i3wm-dotfiles
stow -n -v --no-folding <pkg>…    # dry-run first
stow -v --no-folding <pkg>…
```

Fonts: `fc-cache -fv` after `fonts` changes.  
i3: `i3-msg reload` (or restart) after i3 config changes.  
Vicinae: `systemctl --user try-reload-or-restart vicinae.service` after settings changes.

## Conflict handling

If Stow refuses because a **real file** blocks a symlink:

1. Do **not** `--adopt` unless the user explicitly wants the live file as SSOT.
2. Move the blocker aside (`*.pre-stow` / `*.pre-restore`).
3. Restow so the repo file wins.
4. Especially for `~/.zshrc` and `~/.config/vicinae/settings.json`.

## zsh PATH / tooling

- PATH for cargo, bun, opencode, cursor, pnpm, nvm default node lives **only** in `zsh/.zshrc`.
- Restore script may refresh PATH for the install session and must restore `zsh/.zshrc` if installers clobber it.
- Plugins: git submodules under `zsh/.zsh/plugins/` — `git submodule update --init --recursive`.

## Fresh machine / tooling installs

Use `bash ~/i3wm-dotfiles/extra/restore-fedora.sh` (idempotent-ish). It configures dnf, installs stack, stows packages, then on **full success** runs `gh auth login` if not already logged in. Do not invent a second bootstrap path unless the user asks.

## Commit discipline

Only commit when the user asks. Follow repo commit style (short why-focused messages). Do not commit secrets (`.env`, private keys).
