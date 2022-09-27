#
# ~/.bash_profile
#
[[ -f ~/.bashrc ]] && . ~/.bashrc
[ "$(tty)" = "/dev/tty1" ] && exec startx
#[ "$(tty)" = "/dev/tty1" ] && WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 sway --unsupported-gpu
