#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

eval "$(starship init bash)"
alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
fish
