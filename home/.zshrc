export PATH="$PATH:/home/$USER/script"
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
alias p='ALL_PROXY=127.0.0.1:7890'
alias X='unset WAYLAND_DISPLAY && QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 DISPLAY=:1 DESKTOP_SESSION=xfce XDG_CURRENT_DESKTOP=XFCE XDG_SESSION_TYPE=x11 XDG_MENU_PREFIX=xfce-'
#alias gamemoderun='gamemoderun gamescope -w 1920 -h 1080 -r 144 -rt -e -f --prefer-vk-device -U -- %command%'

# plugins
eval "$(starship init zsh)"
eval "$(mcfly init zsh)"
eval "$(zoxide init zsh)"
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
#fpath=(usr/share/zsh/site-functions/ $fpath)
#bindkey '^[[A' history-substring-search-up
#bindkey '^[[B' history-substring-search-down

#if [[ $(ps --no-header --pid=$PPID --format=cmd) != "fish" ]]
#then
#    exec fish
#fi

source /home/hydroakri/.config/broot/launcher/bash/br
