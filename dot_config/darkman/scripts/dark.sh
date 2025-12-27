#!/bin/sh
# Dark mode commands
plasma-apply-colorscheme Flexoki-Dark
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Adw-gtk3-dark
gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
cp ~/.config/gtk-3.0/gtk-flexoki-dark.css ~/.config/gtk-3.0/gtk.css
cp ~/.config/gtk-4.0/gtk-flexoki-dark.css ~/.config/gtk-4.0/gtk.css
sed -i "/^style/s/=.*/=Adwaita-dark/" ~/.config/qt6ct/qt6ct.conf
sed -i '/^icon_theme/s/=.*/=Papirus-Dark/' ~/.config/qt6ct/qt6ct.conf
sed -i "/^color_scheme_path/s|=.*|=~/.config/qt6ct/colors/flexoki-dark.conf|" ~/.config/qt6ct/qt6ct.conf
