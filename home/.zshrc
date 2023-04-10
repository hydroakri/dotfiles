export PATH="$PATH:/home/hydroakri"

autoload -U compinit
autoload -U promptinit
promptinit
compinit
setopt HIST_IGNORE_DUPS
zstyle ':completion:*' menu select
zstyle ':completion:*' rehash true
[[ -n "${key[PageUp]}"   ]]  && bindkey  "${key[PageUp]}"    history-beginning-search-backward
[[ -n "${key[PageDown]}" ]]  && bindkey  "${key[PageDown]}"  history-beginning-search-forward

eval "$(starship init zsh)"
eval "$(mcfly init zsh)"
eval "$(zoxide init bash)"
export EDITOR=nvim
alias sudo='doas'
alias sudoedit='doas rnano'
alias vim='nvim'
alias vi='nvim'
alias ls='lsd'
alias find='fd'
alias grep='rg'
alias ack='ag'
alias cd='z'
alias fzf='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" '
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
alias neovide='WINIT_UNIX_BACKEND=x11 neovide'
