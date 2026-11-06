autoload -Uz compinit
compinit

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export EDITOR="vi"

# History
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=100000
export SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

eval "$(zoxide init zsh)"

alias cd="z"
alias zconf="vi ~/.zshrc"
alias reload="source ~/.zshrc"
alias shadcn="pnpm dlx shadcn@latest"
alias cat="bat"
alias ls="eza --long --icons --classify=auto"
alias glo="git log --oneline --graph"
alias vpnc="protonvpn connect"
alias vpnd="protonvpn disconnect"

export NVM_DIR="$HOME/.nvm"

# Put the default Node bin on PATH. nvm.sh is thousands of lines, so it loads
# only when `nvm` itself is run.
_nvm_default_bin() {
  local spec="$NVM_DIR/alias/default" step=0 matches
  [[ -r $spec ]] || return 1
  spec=${$(<$spec)%%[[:space:]]*}
  while (( step++ < 8 )); do
    if [[ -x "$NVM_DIR/versions/node/$spec/bin/node" ]]; then
      print -r -- "$NVM_DIR/versions/node/$spec/bin"
      return
    elif [[ -x "$NVM_DIR/versions/node/v$spec/bin/node" ]]; then
      print -r -- "$NVM_DIR/versions/node/v$spec/bin"
      return
    elif [[ -r "$NVM_DIR/alias/$spec" ]]; then
      spec=${$(<"$NVM_DIR/alias/$spec")%%[[:space:]]*}
    else
      matches=( "$NVM_DIR"/versions/node/v${spec}.*(NnOn) )
      (( $#matches )) || return 1
      print -r -- "$matches[-1]/bin"
      return
    fi
  done
  return 1
}
if nvm_node_bin=$(_nvm_default_bin 2>/dev/null); then
  export PATH="$nvm_node_bin:$PATH"
fi
unset -f _nvm_default_bin
unset nvm_node_bin

nvm() {
  unset -f nvm
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
  nvm "$@"
}

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac

eval "$(starship init zsh)"

source ~/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh
# add-zle-hook-widget before zvm_init makes zsh 5.9 SIGSEGV in `$(zle -l)`.
zvm_after_init_commands+=(
  'source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'
  'source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh'
)

autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
