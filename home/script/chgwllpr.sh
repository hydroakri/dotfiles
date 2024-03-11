#!/bin/bash
############################ change wallpaper ##############################
swww img $(find ~/Pictures/wllppr/. -name '*.*g' | shuf -n1) --transition-step 144 --transition-type wipe --transition-angle 61.8
# swaybg -i $(find ~/Pictures/wllppr/. -name "*.*g" | shuf -n1) -m fill

######################### generate theme according to wallpaper ############
current_paper=$(swww query | grep -o 'image: .*' | cut -d ' ' -f 2-)
random_lockscreen=$(find ~/Pictures/wllppr -name '*.png' | shuf -n1)
# wal -l -i $current_paper
wal -i $current_paper
. "${HOME}/.cache/wal/colors.sh"

####################### chane hyprlock paper ###############################
sed -i "0,/^ *path.*/{s,,    path=$random_lockscreen,}" ~/.config/hypr/hyprlock.conf


############################# change mako theme ################################
sed -i "0,/^background-color.*/{s//background-color=$color6/}" ~/.config/mako/config
sed -i "0,/^text-color.*/{s//text-color=$color0/}" ~/.config/mako/config
makoctl reload

############################## change zellij theme ##########################
if [ ! -e "~/.cache/wal/wezterm.toml"]; then
touch ~/.cache/wal/wezterm.toml
fi
: > ~/.config/zellij/themes/pywal.kdl # clear file content
echo "themes {" >> ~/.config/zellij/themes/pywal.kdl
echo "    default {" >> ~/.config/zellij/themes/pywal.kdl
echo "        fg \"$color0\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        bg \"$color1\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        black \"$foreground\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        red \"$color2\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        green \"$color3\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        yellow \"$color4\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        blue \"$color5\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        magenta \"$color6\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        cyan \"$color7\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        white \"$color8\"" >> ~/.config/zellij/themes/pywal.kdl
echo "        orange \"$color9\"" >> ~/.config/zellij/themes/pywal.kdl
echo "    }" >> ~/.config/zellij/themes/pywal.kdl
echo "}" >> ~/.config/zellij/themes/pywal.kdl

################################ wezterm ###############################
if [ ! -e "~/.cache/wal/wezterm.toml"]; then
touch ~/.cache/wal/wezterm.toml
fi
: > ~/.cache/wal/wezterm.toml
echo "[colors]"
echo "ansi = ["
echo "    '',"
echo "    '$color0',"
echo "    '$color1',"
echo "    '$color2',"
echo "    '$color3',"
echo "    '$color4',"
echo "    '$color5',"
echo "    '$color6',"
echo "]"
echo "background = '$background'"
echo "brights = ["
echo "    '$color7',"
echo "    '$color8',"
echo "    '$color9',"
echo "    '$color11',"
echo "    '$color12',"
echo "    '$color13',"
echo "    '$color14',"
echo "    '$color15',"
echo "]"
echo "cursor_bg = '$cursor'"
echo "cursor_border = '$cursor'"
echo "cursor_fg = '$cursor'"
echo "foreground = '$foreground'"
echo "selection_bg = '$cursor'"
echo "selection_fg = '$cursor'"
echo ""
echo "[colors.indexed]"
echo ""
echo "[metadata]"
echo "author = 'Chris Kempson (http://chriskempson.com)'"
echo "name = 'Cupcake'"
