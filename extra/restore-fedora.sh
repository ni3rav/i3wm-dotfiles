#!/usr/bin/env bash
# Fresh Fedora + i3wm restore for ~/i3wm-dotfiles
# Modular, idempotent-ish steps. Re-run safely; failed steps are reported and skipped past.
#
# Usage:
#   bash ~/i3wm-dotfiles/extra/restore-fedora.sh
#   DOTFILES_DIR=/path/to/i3wm-dotfiles bash extra/restore-fedora.sh

set -u
set -o pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/i3wm-dotfiles}"
FAILED=()
STARTED_AT=$(date -Iseconds)

# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Keep the install session PATH useful before zshrc is active.
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${HOME}/.bun/bin:${HOME}/.opencode/bin:${HOME}/.cursor/bin:${PATH}"

refresh_path() {
  export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${HOME}/.bun/bin:${HOME}/.opencode/bin:${HOME}/.cursor/bin:${PATH}"
  # shellcheck disable=SC1090
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
  # shellcheck disable=SC1090
  [[ -f "${HOME}/.bun/bin/bun" ]] && export BUN_INSTALL="${HOME}/.bun" && export PATH="${BUN_INSTALL}/bin:${PATH}"
  if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    source "${HOME}/.nvm/nvm.sh"
  fi
}

run_step() {
  local title=$1
  shift
  log "$title"
  if "$@"; then
    ok "$title"
    return 0
  fi
  err "$title"
  FAILED+=("$title")
  return 0
}

have_copr() {
  # dnf5/dnf4: list enabled COPRs
  dnf copr list 2>/dev/null | grep -Fq "$1"
}

ensure_copr() {
  local name=$1
  if have_copr "$name"; then
    ok "COPR already enabled: $name"
    return 0
  fi
  sudo dnf copr enable -y "$name"
}

# Append a block to a file once (marker-guarded).
ensure_block() {
  local file=$1 marker=$2 block=$3
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fq "$marker" "$file" 2>/dev/null; then
    ok "PATH block already present in $file ($marker)"
    return 0
  fi
  {
    printf '\n# %s\n' "$marker"
    printf '%s\n' "$block"
  } >>"$file"
  ok "Added PATH block to $file ($marker)"
}

# -----------------------------------------------------------------------------
# 0) DNF config + upgrade
# -----------------------------------------------------------------------------

configure_dnf() {
  sudo tee /etc/dnf/dnf.conf >/dev/null <<'EOF'
# see `man dnf.conf` for defaults and possible options

[main]
max_parallel_downloads=10
fastestmirror=True
timeout=30
minrate=10k
EOF
}

step_dnf_config() {
  configure_dnf
}

step_dnf_upgrade() {
  sudo dnf upgrade -y
}

# -----------------------------------------------------------------------------
# 1) Core packages (NO starship — that comes from COPR)
# -----------------------------------------------------------------------------

step_core_packages() {
  sudo dnf install -y \
    git curl wget stow zsh zoxide fzf eza bat \
    golang fd-find ripgrep fontconfig util-linux-user flatpak \
    python3-pip \
    i3 i3status i3lock xss-lock dmenu \
    NetworkManager-gnome dex \
    wmctrl xdotool \
    xorg-x11-xkb-utils \
    nautilus \
    jq
}

# -----------------------------------------------------------------------------
# Starship via COPR (required by zshrc; not part of plain core dnf set)
# -----------------------------------------------------------------------------

step_starship() {
  ensure_copr "atim/starship"
  sudo dnf install -y starship
}

# -----------------------------------------------------------------------------
# 2) zsh login shell
# -----------------------------------------------------------------------------

step_zsh_shell() {
  local zsh_path
  zsh_path=$(command -v zsh)
  [[ -n "$zsh_path" ]] || { err "zsh not installed"; return 1; }
  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    ok "login shell already zsh"
    return 0
  fi
  sudo chsh -s "$zsh_path" "$USER"
}

# -----------------------------------------------------------------------------
# 3) Go (dnf already) + Rust (rustup), PATH
# -----------------------------------------------------------------------------

step_golang() {
  # ensured by core; verify
  need_cmd go || sudo dnf install -y golang
  go version
}

step_rust() {
  if need_cmd rustc && need_cmd cargo; then
    ok "rust already installed: $(rustc --version)"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path
  fi
  refresh_path
  # Persist PATH for interactive zsh (stowed zshrc also sources cargo if present)
  ensure_block "$HOME/.zshrc.local" "i3wm-dotfiles:cargo" \
'source "$HOME/.cargo/env" 2>/dev/null'
  # Prefer tracked zshrc when it is already the stow target
  if [[ -L "$HOME/.zshrc" ]]; then
    local zshrc
    zshrc=$(readlink -f "$HOME/.zshrc")
    if ! grep -Fq '.cargo/env' "$zshrc" 2>/dev/null; then
      ensure_block "$zshrc" "i3wm-dotfiles:cargo" \
'[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"'
    fi
  fi
  rustc --version
  cargo --version
}

# -----------------------------------------------------------------------------
# Ghostty + Vicinae (needed by these dotfiles)
# -----------------------------------------------------------------------------

step_ghostty() {
  ensure_copr "scottames/ghostty"
  sudo dnf install -y ghostty
}

step_vicinae() {
  ensure_copr "quadratech188/vicinae"
  sudo dnf install -y vicinae
  systemctl --user enable --now vicinae.service || true
}

step_i3_layouts() {
  refresh_path
  python3 -m pip install --user -U i3-layouts
  refresh_path
  need_cmd i3-layouts
}

# -----------------------------------------------------------------------------
# 4) Helium
# -----------------------------------------------------------------------------

step_helium() {
  ensure_copr "imput/helium"
  sudo dnf install -y helium-bin
}

# -----------------------------------------------------------------------------
# 5) Charm (glow)
# -----------------------------------------------------------------------------

step_charm() {
  if [[ ! -f /etc/yum.repos.d/charm.repo ]]; then
    printf '%s\n' \
      '[charm]' \
      'name=Charm' \
      'baseurl=https://repo.charm.sh/yum/' \
      'enabled=1' \
      'gpgcheck=1' \
      'gpgkey=https://repo.charm.sh/yum/gpg.key' \
      | sudo tee /etc/yum.repos.d/charm.repo >/dev/null
  fi
  sudo dnf install -y glow
}

# -----------------------------------------------------------------------------
# 6) Bun + PATH
# -----------------------------------------------------------------------------

step_bun() {
  if need_cmd bun; then
    ok "bun already installed: $(bun --version)"
  else
    curl -fsSL https://bun.sh/install | bash
  fi
  refresh_path
  ensure_block "$HOME/.zshrc.local" "i3wm-dotfiles:bun" \
'export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"'
  bun --version
}

# -----------------------------------------------------------------------------
# 7) NVM + Node LTS/Current + pnpm
# -----------------------------------------------------------------------------

step_nvm_node_pnpm() {
  export NVM_DIR="${HOME}/.nvm"
  if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh \
      | PROFILE=/dev/null bash
  else
    ok "nvm already present"
  fi
  # shellcheck disable=SC1090
  source "${NVM_DIR}/nvm.sh"
  nvm install --lts
  nvm install node
  nvm alias default 'lts/*'
  nvm use --lts
  corepack enable
  corepack prepare pnpm@latest --activate
  nvm use node
  corepack enable
  corepack prepare pnpm@latest --activate
  nvm alias default 'lts/*'
  nvm use default
  ensure_block "$HOME/.zshrc.local" "i3wm-dotfiles:nvm-hint" \
'# Node via nvm is configured in ~/.zshrc (stowed). Default node bin is on PATH there.'
  node --version
  pnpm --version
}

# -----------------------------------------------------------------------------
# 8 / 12) uv
# -----------------------------------------------------------------------------

step_uv() {
  if need_cmd uv; then
    ok "uv already installed: $(uv --version)"
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  refresh_path
  ensure_block "$HOME/.zshrc.local" "i3wm-dotfiles:uv" \
'export PATH="$HOME/.local/bin:$PATH"'
  uv --version
}

# -----------------------------------------------------------------------------
# 9 / 13) OpenCode
# -----------------------------------------------------------------------------

step_opencode() {
  if need_cmd opencode; then
    ok "opencode already installed"
  else
    curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
  fi
  refresh_path
  ensure_block "$HOME/.zshrc.local" "i3wm-dotfiles:opencode" \
'export PATH="$HOME/.opencode/bin:$PATH"'
  need_cmd opencode && opencode --version || true
}

# -----------------------------------------------------------------------------
# 10) VS Code
# -----------------------------------------------------------------------------

step_vscode() {
  if need_cmd code; then
    ok "code already installed"
    return 0
  fi
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  printf '%s\n' \
    '[code]' \
    'name=Visual Studio Code' \
    'baseurl=https://packages.microsoft.com/yumrepos/vscode' \
    'enabled=1' \
    'autorefresh=1' \
    'type=rpm-md' \
    'gpgcheck=1' \
    'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' \
    | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
  sudo dnf install -y code
}

# -----------------------------------------------------------------------------
# 11) Cursor CLI
# -----------------------------------------------------------------------------

step_cursor_cli() {
  curl -fsS https://cursor.com/install | bash
  refresh_path
  ensure_block "$HOME/.zshrc.local" "i3wm-dotfiles:cursor-cli" \
'export PATH="$HOME/.local/bin:$HOME/.cursor/bin:$PATH"'
  # binary name varies (cursor / agent); report what we got
  need_cmd cursor && cursor --version || true
  need_cmd agent && ok "cursor agent present" || true
}

# -----------------------------------------------------------------------------
# 14) Flathub + OBS + OnlyOffice
# -----------------------------------------------------------------------------

step_flatpaks() {
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub com.obsproject.Studio
  flatpak install -y flathub org.onlyoffice.desktopeditors
}

# -----------------------------------------------------------------------------
# 15) Submodules + stow + fonts
# -----------------------------------------------------------------------------

step_dotfiles() {
  [[ -d "$DOTFILES_DIR" ]] || { err "DOTFILES_DIR missing: $DOTFILES_DIR"; return 1; }
  cd "$DOTFILES_DIR"

  git submodule update --init --recursive

  mkdir -p "$HOME/.config/vicinae"

  # Relocate blocking real ~/.zshrc if needed (do not clobber a symlink)
  if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    warn "moving real ~/.zshrc aside so stow can link"
    mv "$HOME/.zshrc" "$HOME/.zshrc.pre-restore"
  fi

  stow -v --no-folding \
    i3 vicinae zsh starship ghostty fonts git code cursor

  # Ensure interactive zsh loads cargo + optional local overrides after stow
  if [[ -L "$HOME/.zshrc" ]]; then
    local zshrc
    zshrc=$(readlink -f "$HOME/.zshrc")
    if ! grep -Fq '.cargo/env' "$zshrc" 2>/dev/null; then
      ensure_block "$zshrc" "i3wm-dotfiles:cargo" \
'[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"'
    fi
    if ! grep -Fq '.zshrc.local' "$zshrc" 2>/dev/null; then
      ensure_block "$zshrc" "i3wm-dotfiles:zshrc.local" \
'[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"'
    fi
  fi

  fc-cache -fv
}

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------

main() {
  log "i3wm-dotfiles restore starting ($STARTED_AT)"
  log "DOTFILES_DIR=$DOTFILES_DIR"

  run_step "Configure /etc/dnf/dnf.conf" step_dnf_config
  run_step "Upgrade system packages" step_dnf_upgrade
  run_step "Install core packages (no starship)" step_core_packages
  run_step "Install starship from COPR" step_starship
  run_step "Set zsh as login shell" step_zsh_shell
  run_step "Verify Go toolchain" step_golang
  run_step "Install Rust (rustup) + PATH" step_rust
  run_step "Install Ghostty (COPR)" step_ghostty
  run_step "Install Vicinae (COPR) + user service" step_vicinae
  run_step "Install i3-layouts (pip --user)" step_i3_layouts
  run_step "Install Helium" step_helium
  run_step "Install Charm (glow)" step_charm
  run_step "Install Bun + PATH" step_bun
  run_step "Install NVM, Node LTS/Current, pnpm" step_nvm_node_pnpm
  run_step "Install uv + PATH" step_uv
  run_step "Install OpenCode + PATH" step_opencode
  run_step "Install VS Code" step_vscode
  run_step "Install Cursor CLI" step_cursor_cli
  run_step "Install Flatpak apps (OBS, OnlyOffice)" step_flatpaks
  run_step "Submodules + stow packages + fc-cache" step_dotfiles

  printf '\n'
  if ((${#FAILED[@]})); then
    warn "Finished with ${#FAILED[@]} failed step(s):"
    for f in "${FAILED[@]}"; do err "$f"; done
    printf '\nRe-run the script to retry failed steps.\n'
    return 1
  fi

  ok "Restore finished successfully."
  printf 'Open a new terminal (or log out/in) so zsh + PATH are active.\n'
  printf 'Optional: apply Firefox prefs from extra/firefox_user.js to a profile.\n'
}

main "$@"
