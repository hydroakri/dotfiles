#!/bin/sh
# Light mode commands
plasma-apply-colorscheme Flexoki-Light
gsettings set org.gnome.desktop.interface color-scheme prefer-light
gsettings set org.gnome.desktop.interface gtk-theme Adw-gtk3
gsettings set org.gnome.desktop.interface icon-theme Papirus
cp ~/.config/gtk-3.0/gtk-flexoki-light.css ~/.config/gtk-3.0/gtk.css
cp ~/.config/gtk-4.0/gtk-flexoki-light.css ~/.config/gtk-4.0/gtk.css
sed -i "/^style/s/=.*/=Adwaita/" ~/.config/qt6ct/qt6ct.conf
sed -i '/^icon_theme/s/=.*/=Papirus/' ~/.config/qt6ct/qt6ct.conf
sed -i "/^color_scheme_path/s|=.*|=~/.config/qt6ct/colors/flexoki-light.conf|" ~/.config/qt6ct/qt6ct.conf
