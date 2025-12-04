{ config, lib, pkgs, ... }: {
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
  services.chrony = {
    enable = true;
    servers = [ "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" ];
  };
  programs.nh.enable = true;
  programs.nix-ld.enable = true;
  programs.git = {
    enable = true;
    config = {
      init = { defaultBranch = "main"; };
      url = {
        "ssh://git@github.com/" = {
          pushInsteadOf = [ "https://github.com/" ];
        };
      };
    };
  };
  environment.systemPackages = with pkgs;
    [
      xz
      age
      fzf
      bat
      zip
      gdu
      sops
      file
      fish
      wget
      lsof
      btop
      yazi
      unzip
      unrar
      p7zip
      atuin
      neovim
      zoxide
      chezmoi
      lazygit
      ripgrep
      nix-tree
      starship
      pciutils
      fastfetch
      ssh-to-age
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ efibootmgr mokutil ];
  system.stateVersion = "25.11"; # Did you read the comment?
}
