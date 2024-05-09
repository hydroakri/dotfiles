current_paper=$(find ~/Pictures/wllppr/. -name '*.*g' | shuf -n1)
random_lockscreen=$(find ~/Pictures/wllppr -name '*.png' | shuf -n1)

############################ change wallpaper ##############################
# swww img $current_paper --transition-step 24
swaybg -i $current_paper -m fill

####################### change hyprlock paper ###############################
sed -i "0,/^ *path.*/{s,,    path=$random_lockscreen,}" ~/.config/hypr/hyprlock.conf
