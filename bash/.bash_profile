#
# ~/.bash_profile
#
[[ -f ~/.bashrc ]] && . ~/.bashrc


[ "$(tty)" = "/dev/tty1" ] && ./selgra

#[ "$(tty)" = "/dev/tty1" ] && exec startx
#only laptop screen
#[ "$(tty)" = "/dev/tty1" ] && Hyprland
#[ "$(tty)" = "/dev/tty2" ] && WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 Hyprland
# only extened screen
#[ "$(tty)" = "/dev/tty1" ] && WLR_DRM_DEVICES=/dev/dri/card1:/dev/drm/card0 sway --unsupported-gpu
export EDITOR=nvim
alias sudo='doas'
alias sudoedit='doas rnano'
alias vim='nvim'
alias vi='nvim'
alias neovide='env -u WAYLAND_DISPLAY neovide'
#alias neovide='WINIT_UNIX_BACKEND=x11 neovide'
