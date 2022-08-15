#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

eval "$(starship init bash)"
# Use bash-completion, if available
[[ $PS1 && -f /usr/share/bash-completion/completion ]] && \
    . /usr/share/bash-completion/completion

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
