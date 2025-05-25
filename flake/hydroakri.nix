{ config, pkgs, ... }: {
  home.username = "hydroakri";
  home.homeDirectory = "/home/hydroakri";
  imports = [ ];
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 96;
  };
  programs.git.enable = true;
  programs.zsh = {
    enable = true;
    initContent = ''
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
}
