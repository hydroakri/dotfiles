# Easy-to-extend dotfiles with reasonable defaults
I'm a lazy person, I'm often annoyed by the amount of scripts and scattered files that I can find to configure, so I created this repository so that you can apply the programs you want to take effect as you need. I try to make each application or module as easy to copy as possible by default
![](./preview.png)
# Installation
first make sure you have installed the `stow`  
I use `stow` for unified file management

## For Chinese users
You can use ssh to speed up git clone
```
git config --global --add url."git@github.com:".insteadOf "https://github.com/"
```

```
sudo apt install stow # for ubuntu
sudo pacman -S stow  # for archlinux
pkg install stow # for freebsd
```
before you apply the conf, You MUST make sure that you have backed up your configuration  
For example: if you want to apply the config of my polybar, you should:
```
cd ~
git clone https://github.com/hydroakri/dotfiles.git
cd dotfiles
stow polybar
```

|       Program       |                                                             Name                                                              |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------: |
|    Window Manger    |     [i3wm](https://i3wm.org/),[sway](https://github.com/swaywm/sway)                                                              |
|         Bar         |     [polybar](https://github.com/polybar/polybar),[waybar](https://github.com/Alexays/Waybar)|
|     Compositor      |     [picom-jonaburg-git](https://github.com/jonaburg/picom)                                  |
|      Launcher       |     [rofi](https://github.com/davatorium/rofi)                                           |
|  Wallpaper Setter   |     [nitrogen](https://archlinux.org/packages/?name=nitrogen)                                              |
|     Web Browser     |     [edge](https://aur.archlinux.org/packages/microsoft-edge-stable-bin)                      |
|      Terminal       |     [Alacritty](https://github.com/alacritty/alacritty), [starship](https://starship.rs/)                                      |
|        Shell        |     [fish](https://www.fishshell.com)                                            |
|     Code Editor     |     [neovim](https://neovim.io/) ([neovide](https://github.com/neovide/neovide))                                     |
| Notification daemon |     [dunst](https://dunst-project.org/)                                              |
|        Fetch        |     [fastfetch](https://github.com/LinusDierheimer/fastfetch)                                 |
|       Media         |     [mpv](https://mpv.io/), [nomacs](https://nomacs.org/), [obs-studio](https://obsproject.com/), [yesplaymusic](https://github.com/qier222/YesPlayMusic), [cider](https://cider.sh/)        |
|        misc         |     [lsd](https://github.com/Peltoche/lsd), [bat](https://github.com/sharkdp/bat), [fd](https://github.com/sharkdp/fd), [ripgrep](https://github.com/BurntSushi/ripgrep), [ranger(require w3m)](https://github.com/ranger/ranger), [scrcpy](https://github.com/Genymobile/scrcpy), [stow](https://www.gnu.org/software/stow/), [tlp](https://linrunner.de/tlp/index.html), [lazygit](https://github.com/jesseduffield/lazygit) [zellij](https://github.com/zellij-org/zellij)|
|       fonts         |     [awesome-terminal-fonts](https://archlinux.org/packages/community/any/awesome-terminal-fonts/), [nerd-fonts-sarasa-mono](https://aur.archlinux.org/packages/nerd-fonts-sarasa-mono), [noto-fonts-cjk](https://archlinux.org/packages/extra/any/noto-fonts-cjk/), [ttf-font-awesome](https://archlinux.org/packages/community/any/ttf-font-awesome/)      |
|   Chinese Input     |     sudo pacman -Sy fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-rime fcitx5-qt                                |
|   system monitor    |     [btop](https://github.com/aristocratos/btop)                                |
|      screenshot     |     [flameshot](https://flameshot.org/)                                                  |
|  download manager   |     [motrix](https://motrix.app/)                                                        |
| themes & the manager|     [dracula](https://draculatheme.com/), icon:[papirus-icon-theme](https://aur.archlinux.org/packages/papirus-icon-theme-git), [lxappearance](https://github.com/lxde/lxappearance)  qt5ct               |
|   settings          |     [network-manager-applet](https://archlinux.org/packages/extra/x86_64/network-manager-applet/), X11:[arandr](https://christian.amsuess.com/tools/arandr/), wayland:[wdisplays-git](https://github.com/artizirk/wdisplays), [blueman](https://github.com/blueman-project/blueman) polkit-gnome xf86-input-synaptics autorandr nitrogen pavucontrol|




# license
all files and scripts in this repo are released [CC0](https://creativecommons.org/publicdomain/zero/1.0/)  in the spirit of _freedom of information_, i encourage you to fork, modify, change, share, or do whatever you like with this project! `^c^v`
