#!/usr/bin/env sh
if [ "$(hyprctl getoption decoration:rounding | awk 'NR==2{print $2}')" = 9 ] ; then
    hyprctl --batch "\
        # keyword decoration:blur:enabled false; \
        keyword general:gaps_in 0; \
        keyword general:gaps_out 0; \
        keyword decoration:rounding 0; \
        # keyword decoration:drop_shadow 0; "
    exit
fi
hyprctl reload
