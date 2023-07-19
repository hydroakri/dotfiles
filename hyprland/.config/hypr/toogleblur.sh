#!/usr/bin/env sh
if [ "$(hyprctl getoption decoration:blur | awk 'NR==2{print $2}')" = 0 ] ; then
    hyprctl --batch "keyword decoration:blur 1; keyword decoration:active_opacity 0.9; keyword decoration:inactive_opacity 0.9"
    exit
fi
hyprctl reload
