{ config, pkgs, lib, ... }:
let rime-ice-path = ".local/share/fcitx5/";
in {
  home.username = "hydroakri";
  home.homeDirectory = "/home/hydroakri";
  imports = [ ];
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 96;
  };
  programs.fish.enable = true;
  home.packages = with pkgs; [
    # themes/shell/plugin
    bibata-cursors
    papirus-icon-theme
    gnomeExtensions.appindicator
    gnomeExtensions.user-themes
    gnomeExtensions.kimpanel
    gnome-tweaks

    # dev tools
    gcc
    cargo
    nodejs
    python3

    # GUI APplications
    flatpak
    kdePackages.kate
    venera
    ghostty
    code-cursor
    # davinci-resolve-studio
  ];
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  home.file = {
    ".zshrc".source = ../dot_zshrc;
    ".config" = {
      source = ../dot_config;
      recursive = true;
      executable = true;
    };
    ".local" = {
      source = ../dot_local;
      recursive = true;
      executable = true;
    };
    ".ssh" = {
      source = ../dot_ssh;
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
      wantedBy = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "watch-store" ''
        #!/run/current-system/sw/bin/bash
        mkdir -p "${rime-ice-path}"
        if [ ! -d "${rime-ice-path}/rime/.git" ]; then
          "${pkgs.git}/bin/git" clone https://github.com/iDvel/rime-ice "${rime-ice-path}/rime"
        else
          cd "${rime-ice-path}/rime"
          "${pkgs.git}/bin/git" pull --ff-only
        fi
      ''}";
    };

    Install = { WantedBy = [ "default.target" ]; };
  };

}
