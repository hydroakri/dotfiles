#!/bin/bash
############################ change wallpaper ##############################
swww img $(find ~/Pictures/wllppr/. -name '*.*g' | shuf -n1) --transition-step 24
# swaybg -i $(find ~/Pictures/wllppr/. -name "*.*g" | shuf -n1) -m fill

####################### change hyprlock paper ###############################
random_lockscreen=$(find ~/Pictures/wllppr -name '*.png' | shuf -n1)
sed -i "0,/^ *path.*/{s,,    path=$random_lockscreen,}" ~/.config/hypr/hyprlock.conf

######################### generate theme according to wallpaper ############
~/script/chtheme.sh
