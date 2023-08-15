#!/usr/bin/env sh
if [ "$(hyprctl getoption decoration:active_opacity | awk 'NR==3{print $2}')" = 1.000000 ] ; then
    hyprctl --batch "keyword decoration:blur:enabled true; keyword decoration:active_opacity 0.9; keyword decoration:inactive_opacity 0.9"
    exit
fi
hyprctl reload
