#
# ~/.bash_profile
#
[[ -f ~/.bashrc ]] && . ~/.bashrc
[ "$(tty)" = "/dev/tty1" ] && exec startx

#only laptop screen
#[ "$(tty)" = "/dev/tty1" ] && WLR_DRM_DEVICES=/dev/dri/card0:/dev/drm/card1 sway --unsupported-gpu

# only extened screen
#[ "$(tty)" = "/dev/tty1" ] && WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 sway --unsupported-gpu
