#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

eval "$(starship init bash)"
export EDITOR=nvim
export PATH="$PATH:/home/hydroakri"
alias sudo='doas'
alias sudoedit='doas rnano'
alias vim='nvim'
alias vi='nvim'

#alias neovide='env -u WAYLAND_DISPLAY neovide'
alias neovide='WINIT_UNIX_BACKEND=x11 neovide'

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
