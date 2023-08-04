#!/usr/bin/env sh
if [ "$(hyprctl getoption decoration:blur:enabled | awk 'NR==2{print $2}')" = 0 ] ; then
    hyprctl --batch "keyword decoration:blur:enabled true; keyword decoration:active_opacity 0.9; keyword decoration:inactive_opacity 0.9"
    exit
fi
hyprctl reload
