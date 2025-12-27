{ config, lib, pkgs, inputs, ... }: {
  imports = [ ./options.nix inputs.nix-index-database.nixosModules.default ];
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
      ];
      max-jobs = "auto";
      cores = 0;
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "@wheel" ];
    };
    registry.nixpkgs.flake = inputs.nixpkgs;
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
  boot.kernel.sysctl = { "kernel.sysrq" = 246; };
  console = {
    enable = true;
    earlySetup = true;
    packages = with pkgs; [ terminus_font ];
    # ter-v16n for 1080p below
    # ter-v24n for 1080p
    # ter-v32n for 2K/4K
    font = "ter-v32n";
  };
  time.timeZone = "UTC";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
  networking.networkmanager = {
    enable = true;
    dns = "default";
  };
  networking.nameservers = [ "172.64.36.2" "149.112.112.11" ];
  services.chrony = {
    enable = true;
    servers = [ ];
    extraConfig = ''
      server 129.6.15.27 iburst
      server time.cloudflare.com iburst nts
      server nts.netnod.se iburst nts

      makestep 1.0 3
      ntsdumpdir /var/lib/chrony
    '';
  };
  #SMART monitor
  services.smartd = {
    enable = true;
    defaults.monitored =
      "-a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,35,40";
  };
  users.users.root.shell = pkgs.zsh;
  programs.zsh.enable = true;
  programs.nh.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-index-database.comma.enable = true;
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
      wget
      curl
      unar
      _7zz
      tmux
      python3Minimal
      neovim
      # net utils
      lsof
      iputils
      dnsutils
      nettools
      #hardware
      lshw
      file
      usbutils
      # modern tools 
      fzf
      bat
      gdu
      btop
      yazi
      atuin
      zoxide
      chezmoi
      lazygit
      ripgrep
      starship
      fastfetch
      # nix utils
      nix-tree
      nix-output-monitor
    ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      # x86_64 specific tools
      efibootmgr
      mokutil
      pciutils
    ];
  # XXX: https://nixos.org/manual/nixos/unstable/release-notes
  system.stateVersion = "25.11";
}
