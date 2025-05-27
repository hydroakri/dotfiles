starship init fish | source
atuin init fish | source
zoxide init fish | source

set -x fish_key_bindings fish_vi_key_bindings

set -gx EDITOR nvim

alias cd=__zoxide_z
alias cdi=__zoxide_zi
alias vi='nvim'
alias tmux='tmux -u'
alias fzf='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}" '
alias p='proxychains4 -q'
