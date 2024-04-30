#!/usr/bin/env sh
if [ "$(hyprctl getoption input:repeat_rate | awk 'NR==1{print $2}')" = 50 ] ; then
    notify-send repeate_rate=0
    hyprctl --batch "\
        keyword input:repeat_rate 0; \
        keyword decoration:drop_shadow 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0; "
    exit
else
    hyprctl reload
    notify-send repeate_rate=50
fi

#sudo setcap 'CAP_SYS_NICE=eip' /bin/gamescope # allow gamescope change prosses priority
#sudo setcap 'CAP_SYS_NICE-eip' /bin/gamescope #for undo

# gamemoderun gamescope -w 1920 -h 1080 -W 2560 -H 1440 -r 144 -e -f -U -- steam -gamepadui
# gamemoderun gamescope -w 1920 -h 1080 -W 2560 -H 1440 -r 144 -rt -e -f --prefer-vk-device -U -- %command%

