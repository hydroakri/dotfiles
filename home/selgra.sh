#!/bin/bash
 
echo "----------------------------------"
echo "please enter your choise:"
echo "(0) X11"
echo "(1) gnome wayland"
echo "(2) hyprland"
echo "(3) hyprland ex"
echo "(4) gdm"
echo "(5) plasma-wayland"
echo "(6) plasma-wayland ex"
echo "(9) Exit Menu"
echo "----------------------------------"
read input
 
case $input in
    0)
    sleep 1
    exec startx;;
    1)
    sleep 1
    gnome-shell --wayland;;
    2)
    sleep 1
    Hyprland;;
    3)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card0 Hyprland;;
    4)
    sleep 1
    systemctl start gdm --now;;
    5)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1 startplasma-wayland;;
    6)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0 startplasma-wayland;;
    9)
    exit;;
esac
