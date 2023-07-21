export PATH="$PATH:/home/hydroakri"
SAVEHIST=999999999
HISTFILE=~/.zsh_history
bindkey -v

autoload -U compinit
autoload -U promptinit
promptinit
compinit
setopt HIST_IGNORE_DUPS
zstyle ':completion:*' menu select
zstyle ':completion:*' rehash true

export EDITOR=nvim
alias vi='nvim'
alias ls='lsd'
alias find='fd'
alias grep='rg'
alias ack='ag'
alias cd='z'
alias zj='zellij'
alias fzf='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" '
alias neovide='WINIT_UNIX_BACKEND=x11 neovide'

# plugins
eval "$(starship init zsh)"
eval "$(mcfly init zsh)"
eval "$(zoxide init zsh)"
#source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
#source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
#fpath=(usr/share/zsh/site-functions/ $fpath)
#bindkey '^[[A' history-substring-search-up
#bindkey '^[[B' history-substring-search-down
