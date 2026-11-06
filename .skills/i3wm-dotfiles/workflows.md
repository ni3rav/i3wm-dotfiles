# Workflows

## Edit an existing package

1. Change files under `~/i3wm-dotfiles/<pkg>/…` (or via the live symlink).
2. Dry-run: `stow -n -v --no-folding <pkg>`
3. Apply if needed (usually already linked): `stow -v --no-folding <pkg>`
4. Reload the affected app (i3 / vicinae / new shell / `fc-cache`).
5. Commit only if the user asks.

## Add a new Stow package

1. Pick a short package name (`foo`). Do **not** put it under `extra/` if it should be stowed.
2. Create the package mirroring `$HOME`:

   ```text
   foo/
     .config/foo/config.toml    # → ~/.config/foo/config.toml
     .foorc                     # → ~/.foorc
   ```

3. Prefer **narrow** trees (only files you own). Use `.gitignore` when an app pollutes its config dir (see `code` / `cursor`).
4. Dry-run then stow:

   ```bash
   cd ~/i3wm-dotfiles
   stow -n -v --no-folding foo
   stow -v --no-folding foo
   ```

5. Update:
   - `README.md` packages table
   - `extra/restore-fedora.sh` `step_dotfiles` stow list
   - `.skills/i3wm-dotfiles/reference.md` package map
6. If the package must **never** be stowed, put it under `extra/` or add an ignore rule in `.stow-local-ignore` instead.

## Unstow / restow one package

```bash
stow -D -v --no-folding foo
stow -v --no-folding foo
```

## Installer clobbered ~/.zshrc

Symptoms: `~/.zshrc` is a regular file, or tracked `zsh/.zshrc` gained bun/pnpm/nvm append blocks.

```bash
# Restore tracked content from git if needed, then:
rm -f ~/.zshrc.local
[[ -f ~/.zshrc && ! -L ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.installer-clobber
cd ~/i3wm-dotfiles && stow -v --no-folding zsh
```

Confirm: `[[ -L ~/.zshrc ]] && [[ ! -e ~/.zshrc.local ]]`

## Vicinae settings conflict

If Vicinae rewrote a real `~/.config/vicinae/settings.json`:

```bash
mv ~/.config/vicinae/settings.json ~/.config/vicinae/settings.json.pre-stow
cd ~/i3wm-dotfiles && stow -v --no-folding vicinae
```

Repo settings remain SSOT unless the user wants to merge GUI changes back into the package file.

## Run restore script

```bash
bash ~/i3wm-dotfiles/extra/restore-fedora.sh
```

Expectations:

- Idempotent-ish; failed steps are listed; re-run retries.
- Session PATH only for the install; interactive PATH stays in stowed `.zshrc`.
- Fedora 45+ package names: `nm-connection-editor`, `dex-autostart` (not `NetworkManager-gnome` / `dex`).
- Starship from COPR, not base core set.
- On **full success**, may prompt `gh auth login` if `gh` is installed and not logged in.
- Do not add `.zshrc.local` generation back into the script.

## Validate after bigger changes

```bash
cd ~/i3wm-dotfiles
stow -n -v --no-folding i3 vicinae zsh starship ghostty fonts git code cursor
i3 -C -c ~/.config/i3/config   # if i3 available
fc-list : family | grep -i 'jetbrains\|jakarta'
readlink -f ~/.zshrc           # → …/i3wm-dotfiles/zsh/.zshrc
test ! -e ~/.zshrc.local
```
