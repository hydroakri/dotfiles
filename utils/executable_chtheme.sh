# current_paper=$(swww query | grep -o 'image: .*' | cut -d ' ' -f 2-)
current_hour=$(date +"%H")
qtlight='~\/.config\/qt6ct\/colors\/flexoki-light.conf'
qtdark='~\/.config\/qt6ct\/colors\/flexoki-dark.conf'

if [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 18 ]; then
    plasma-apply-colorscheme Flexoki-Light
    # wal -l -i $current_paper                  # if day light mode
    # wal --theme ~/.config/wal/colorschemes/light/flexoki-light.json
    gsettings set org.gnome.desktop.interface color-scheme prefer-light
    # gsettings set org.gnome.desktop.interface gtk-theme Adwaita
    gsettings set org.gnome.desktop.interface gtk-theme Adw-gtk3
    gsettings set org.gnome.desktop.interface icon-theme Papirus
    cp ~/.config/gtk-3.0/gtk-flexoki-light.css ~/.config/gtk-3.0/gtk.css
    cp ~/.config/gtk-4.0/gtk-flexoki-light.css ~/.config/gtk-4.0/gtk.css
    sed -i "/^style/s/=.*/=Adwaita/" ~/.config/qt6ct/qt6ct.conf
    sed -i '/^icon_theme/s/=.*/=Papirus/' ~/.config/qt6ct/qt6ct.conf
    sed -i "/^color_scheme_path/s|=.*|=$qtlight|" ~/.config/qt6ct/qt6ct.conf
else
    plasma-apply-colorscheme Flexoki-Dark
    # wal -i $current_paper                     # if night dark mode
    # wal --theme ~/.config/wal/colorschemes/dark/flexoki-dark.json
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    # gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
    gsettings set org.gnome.desktop.interface gtk-theme Adw-gtk3-dark
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
    cp ~/.config/gtk-3.0/gtk-flexoki-dark.css ~/.config/gtk-3.0/gtk.css
    cp ~/.config/gtk-4.0/gtk-flexoki-dark.css ~/.config/gtk-4.0/gtk.css
    sed -i "/^style/s/=.*/=Adwaita-dark/" ~/.config/qt6ct/qt6ct.conf
    sed -i '/^icon_theme/s/=.*/=Papirus-Dark/' ~/.config/qt6ct/qt6ct.conf
    sed -i "/^color_scheme_path/s|=.*|=$qtdark|" ~/.config/qt6ct/qt6ct.conf
fi
# . "${HOME}/.cache/wal/colors.sh"
############################# change mako theme ################################
sed -i "0,/^background-color.*/{s//background-color=$background/}" ~/.config/mako/config
sed -i "0,/^text-color.*/{s//text-color=$foreground/}" ~/.config/mako/config
makoctl reload

############################## change zellij theme ##########################
# zellijcolor=~/.config/zellij/themes/pywal.kdl
# if [ ! -f "$zellijcolor" ]; then
#     touch $zellijcolor
# fi
# : > $zellijcolor # clear file content
# echo "themes {" >> $zellijcolor
# echo "    default {" >> $zellijcolor
# echo "        fg \"$foreground\"" >> $zellijcolor
# echo "        bg \"$background\"" >> $zellijcolor
# echo "        black \"$background\"" >> $zellijcolor
# echo "        red \"$color1\"" >> $zellijcolor
# echo "        green \"$color2\"" >> $zellijcolor
# echo "        yellow \"$color3\"" >> $zellijcolor
# echo "        blue \"$color4\"" >> $zellijcolor
# echo "        magenta \"$color5\"" >> $zellijcolor
# echo "        cyan \"$color6\"" >> $zellijcolor
# echo "        white \"$foreground\"" >> $zellijcolor
# echo "        orange \"$color11\"" >> $zellijcolor
# echo "    }" >> $zellijcolor
# echo "}" >> $zellijcolor

################################ wezterm ###############################
# wezcolor=~/.cache/wal/wezterm.toml
# if [ ! -f "$wezcolor" ]; then
#     touch $wezcolor
# fi
# : > $wezcolor
# echo "[colors]" >> $wezcolor
# echo "ansi = [" >> $wezcolor
# echo "    ''," >> $wezcolor
# echo "    '$color0'," >> $wezcolor
# echo "    '$color1'," >> $wezcolor
# echo "    '$color2'," >> $wezcolor
# echo "    '$color3'," >> $wezcolor
# echo "    '$color4'," >> $wezcolor
# echo "    '$color5'," >> $wezcolor
# echo "    '$color6'," >> $wezcolor
# echo "]" >> $wezcolor
# echo "background = '$background'" >> $wezcolor
# echo "brights = [" >> $wezcolor
# echo "    '$color7'," >> $wezcolor
# echo "    '$color8'," >> $wezcolor
# echo "    '$color9'," >> $wezcolor
# echo "    '$color10'," >> $wezcolor
# echo "    '$color11'," >> $wezcolor
# echo "    '$color12'," >> $wezcolor
# echo "    '$color13'," >> $wezcolor
# echo "    '$color14'," >> $wezcolor
# echo "]" >> $wezcolor
# echo "cursor_bg = '$cursor'" >> $wezcolor
# echo "cursor_border = '$cursor'" >> $wezcolor
# echo "cursor_fg = '$cursor'" >> $wezcolor
# echo "foreground = '$foreground'" >> $wezcolor
# echo "selection_bg = '$cursor'" >> $wezcolor
# echo "selection_fg = '$cursor'" >> $wezcolor
# echo "" >> $wezcolor
# echo "[colors.indexed]" >> $wezcolor
# echo "" >> $wezcolor
# echo "[metadata]" >> $wezcolor
# echo "author = 'Chris Kempson (http://chriskempson.com)'" >> $wezcolor
# echo "name = 'pywal'" >> $wezcolor

########################## alacritty ############################
# alacritty=~/.cache/wal/alacritty.toml
# if [ ! -f "$alacritty" ]; then
#     touch $alacritty
# fi
# : > $alacritty
#
# echo "[colors.primary]" >> $alacritty
# echo "background = '$background'" >> $alacritty
# echo "foreground = '$foreground'" >> $alacritty
# echo "" >> $alacritty
# echo "[colors.cursor]" >> $alacritty
# echo "text = '$foreground'" >> $alacritty
# echo "cursor = '$cursor'" >> $alacritty
# echo "" >> $alacritty
# echo "[colors.normal]" >> $alacritty
# echo "black   = '$color0'" >> $alacritty
# echo "red     = '$color1'" >> $alacritty
# echo "green   = '$color2'" >> $alacritty
# echo "yellow  = '$color3'" >> $alacritty
# echo "blue    = '$color4'" >> $alacritty
# echo "magenta = '$color5'" >> $alacritty
# echo "cyan    = '$color6'" >> $alacritty
# echo "white   = '$color7'" >> $alacritty
# echo "" >> $alacritty
# echo "[colors.bright]" >> $alacritty
# echo "black   = '$color8'" >> $alacritty
# echo "red     = '$color9'" >> $alacritty
# echo "green   = '$color10'" >> $alacritty
# echo "yellow  = '$color11'" >> $alacritty
# echo "blue    = '$color12'" >> $alacritty
# echo "magenta = '$color13'" >> $alacritty
# echo "cyan    = '$color14'" >> $alacritty
# echo "white   = '$color15'" >> $alacritty
