{ config, pkgs, lib, ... }:
let
  rime-ice = "https://github.com/iDvel/rime-ice";
  rime-ice-path = ".local/share/fcitx5/rime";
in {
  home.username = "hydroakri";
  home.homeDirectory = "/home/hydroakri";
  imports = [ ];
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 96;
  };
  programs.git.enable = true;
  programs.fish.enable = true;
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

  home.file = {
    ".zshrc".source = ../dot_zshrc;
    ".config" = {
      source = ../private_dot_config;
      recursive = true;
      executable = true;
    };
    ".local" = {
      source = ../dot_local;
      recursive = true;
      executable = true;
    };
    ".ssh" = {
      source = ../private_dot_ssh;
      recursive = true;
      executable = true;
    };
  };

  # 直接以 text 的方式，在 nix 配置文件中硬编码文件内容
  # home.file.".xxx".text = ''
  # xxx
  # '';
  systemd.user.services.gitSyncRime = {
    Unit = {
      Description = "Sync Rime repo from GitHub";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = ''
        if [ -d "${rime-ice-path}/.git" ]; then
          echo "Pulling existing repository at ${rime-ice-path}"
          ${pkgs.git}/bin/git -C "${rime-ice-path}" pull
        else
          echo "Cloning repository to ${rime-ice-path}"
          ${pkgs.git}/bin/git clone ${rime-ice} "${rime-ice-path}"
        fi
      '';
    };

    Install = { WantedBy = [ "default.target" ]; };
  };

  #home.activation.cloneOrPullRepo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #'';
}
