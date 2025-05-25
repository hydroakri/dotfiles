{ config, pkgs, lib, ... }:
let
  rime-ice = "https://github.com/iDvel/rime-ice";
  rime-ice-path = "~/.local/share/fcitx5/rime";
in {
  home.username = "hydroakri";
  home.homeDirectory = "/home/hydroakri";
  imports = [ ];
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 96;
  };
  programs.git.enable = true;
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
  home.packages = with pkgs; [
    # nix related
    nix-output-monitor

    #themes
    bibata-cursors
    papirus-icon-theme

    # Desktop APplications
    flatpak
    nekoray
    kdePackages.kate
    kdePackages.partitionmanager

    # fonts
    #source-han-sans
    #inter
    #nerd-fonts.symbols-only
    #cascadia-code
  ];
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  # 直接将当前文件夹的配置文件，链接到 Home 目录下的指定位置
  home.file.".zshrc".source = ../dot_zshrc;

  # 递归将某个文件夹中的文件，链接到 Home 目录下的指定位置
  home.file.".config" = {
    source = ../private_dot_config;
    recursive = true;
    executable = true;
  };
  home.file.".local" = {
    source = ../dot_local;
    recursive = true;
    executable = true;
  };
  home.file.".ssh" = {
    source = ../private_dot_ssh;
    recursive = true;
    executable = true;
  };

  # 直接以 text 的方式，在 nix 配置文件中硬编码文件内容
  # home.file.".xxx".text = ''
  #     xxx
  # '';
  home.activation.cloneOrPullRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "${rime-ice-path}/.git" ]; then
      echo "Pulling existing repository at ${rime-ice-path}"
      git -C "${rime-ice-path}" pull
    else
      echo "Cloning repository to ${rime-ice-path}"
      git clone ${rime-ice} "${rime-ice-path}"
    fi
  '';
}
