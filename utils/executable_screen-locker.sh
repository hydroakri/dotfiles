#!/bin/sh
swayidle -w timeout 300 'swaylock & swayidle -w timeout 600 "hyprctl dispatch dpms off" resume "hyprctl dispatch dpms on" ' timeout 1800 'systemctl suspend'
