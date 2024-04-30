# alias vi 'nvim'
# alias suvi 'doas nvim -u ~/.config/nvim/init.lua'
# alias sudo 'doas'
# alias ls 'eza'
# alias find 'fd'
# # alias grep 'rg'
# alias ack 'ag'
# alias zj 'zellij'
# alias tmux 'tmux -u'
# alias fzf 'fzf --preview "bat --color=always --style=numbers --line-range=:500 {}"'
# function p
#     env ALL_PROXY=127.0.0.1:2334 all_proxy=127.0.0.1:2334 $argv
# end
# function x
#     env GTK_IM_MODULE=fcitx QT_QPA_PLATFORM=xcb GDK_BACKEND=x11 XDG_SESSION_TYPE=x11 -u=WAYLAND_DISPLAY $argv
# end

# Set vi mode
set -x fish_key_bindings fish_vi_key_bindings

# Load plugins
starship init fish | source
atuin init fish | source
zoxide init fish --cmd cd | source
