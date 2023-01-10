#!/bin/bash
 
echo "----------------------------------"
echo "please enter your choise:"
echo "(0) X11"
echo "(1) gnome wayland"
echo "(2) gnome ex wayland"
echo "(3) hyprland"
echo "(4) hyprland ex"
echo "(5) plasma-x11"
echo "(6) plasma-wayland"
echo "(7) plasma-wayland ex"
echo "(9) Exit Menu"
echo "----------------------------------"
read input
 
case $input in
    0)
    sleep 1
    exec startx;;
    1)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card0:/dev/drm/card1 gnome-shell --wayland;;
    2)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 gnome-shell --replace --wayland;;
    3)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card0:/dev/drm/card1 Hyprland;;
    4)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 Hyprland;;
    5)
    sleep 1
    startplasma-x11;;
    6)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card0:/dev/drm/card1 startplasma-wayland;;
    7)
    sleep 1
    WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 startplasma-wayland;;
    9)
    exit;;
esac
