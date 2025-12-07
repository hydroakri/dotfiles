{ config, lib, pkgs, ... }: {
  imports = [ ./options.nix ];
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
  boot.kernel.sysctl = { "kernel.sysrq" = 244; };
  console = {
    enable = true;
    earlySetup = true;
    packages = with pkgs; [ terminus_font ];
    # ter-v16n for 1080p below
    # ter-v24n for 1080p
    # ter-v32n for 2K/4K
    font = "ter-v32n";
  };
  services.chrony = {
    enable = true;
    servers = [ "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" ];
  };
  programs.nh.enable = true;
  programs.nix-ld.enable = true;
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github.com
        # ProxyCommand nc -X connect -x 127.0.0.1:1080 %h %p
        ServerAliveInterval 10
        Hostname ssh.github.com
        Port 443
    '';
  };
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
      fzf
      bat
      zip
      gdu
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
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      # x86_64 specific tools
      efibootmgr
      mokutil
      pciutils
    ];
  # XXX: https://nixos.org/manual/nixos/unstable/release-notes
  system.stateVersion = "25.11";
}
