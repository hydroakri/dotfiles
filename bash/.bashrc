#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

eval "$(starship init bash)"
export PATH="$PATH:/home/hydroakri"

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
