starship init fish | source
atuin init fish | source
zoxide init fish | source

set -x fish_key_bindings fish_vi_key_bindings

# 一些个人变量
set -gx PATH $PATH /home/$USER/script /var/lib/flatpak/exports/bin ~/.local/share/flatpak/exports/bin /home/linuxbrew/.linuxbrew/bin
set -gx XDG_DATA_DIRS $XDG_DATA_DIRS /var/lib/flatpak/exports/share /home/$USER/.local/share/flatpak/exports/share
set -gx EDITOR nvim
alias vi='nvim'
alias tmux='tmux -u'
alias fzf='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" '
alias p='proxychains4 -q'
