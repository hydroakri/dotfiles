starship init fish | source
atuin init fish | source
zoxide init fish | source

set -x fish_key_bindings fish_vi_key_bindings

# 设置语言环境
set -gx LANG en_US.UTF-8

# 一些个人变量
set -gx PATH $PATH /home/$USER/script /var/lib/flatpak/exports/bin ~/.local/share/flatpak/exports/bin /home/linuxbrew/.linuxbrew/bin
set -gx XDG_DATA_DIRS $XDG_DATA_DIRS /var/lib/flatpak/exports/share /home/$USER/.local/share/flatpak/exports/share
set -gx EDITOR nvim
alias vi='nvim'
alias suvi='sudo nvim -u ~/.config/nvim/init.lua'
alias ack='ag'
alias zj='zellij'
alias tmux='tmux -u'
alias fzf='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" '
alias p='proxychains -q'
alias p4='proxychains4 -q'
alias x='env GTK_IM_MODULE=fcitx QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 XDG_SESSION_TYPE=x11 -u=WAYLAND_DISPLAY '

# 设置 Homebrew 镜像源
set -gx HOMEBREW_API_DOMAIN "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
set -gx HOMEBREW_BOTTLE_DOMAIN "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
set -gx HOMEBREW_BREW_GIT_REMOTE "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
set -gx HOMEBREW_CORE_GIT_REMOTE "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
set -gx HOMEBREW_PIP_INDEX_URL "https://pypi.tuna.tsinghua.edu.cn/simple"

