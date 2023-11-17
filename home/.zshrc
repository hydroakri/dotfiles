export PATH="$PATH:/home/$USER/script"
export LANG=en_US.UTF-8
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
export VISUAL=nvim
alias vi='nvim'
alias sudo='doas'
# alias ls='lsd'
# alias find='fd'
# alias grep='rg'
# alias ack='ag'
alias cd='z'
alias zj='zellij'
alias tmux='tmux -u'
alias fzf='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" '
alias p='all_proxy=127.0.0.1:7890 ALL_PROXY=127.0.0.1:7890'
alias x='unset WAYLAND_DISPLAY && QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 DISPLAY=:1 DESKTOP_SESSION=xfce XDG_CURRENT_DESKTOP=XFCE XDG_SESSION_TYPE=x11 XDG_MENU_PREFIX=xfce-'
#alias gamemoderun='gamemoderun gamescope -w 1920 -h 1080 -r 144 -rt -e -f --prefer-vk-device -U -- %command%'

# plugins
eval "$(starship init zsh)"
eval "$(mcfly init zsh)"
eval "$(zoxide init zsh)"
#git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
#git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#if [[ $(ps --no-header --pid=$PPID --format=cmd) != "fish" ]]
#then
#    exec fish
#fi
