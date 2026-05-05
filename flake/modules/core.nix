{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./options.nix
    ./features/networking/sqm.nix
    ./features/networking/tuning.nix
    inputs.nix-index-database.nixosModules.default
  ];
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;
  nix = {
    package = pkgs.lix;
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://cache.hydroakri.cc/cachix"
        # "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://cache.nixos.org/"
        "https://ros.cachix.org"
      ];
      trusted-public-keys = [
        "cachix:eBckug6/bGXXnIC+i6fms40KxCbstV+wJYV4JMwAvZ4="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
      ];
      max-jobs = "auto";
      cores = 0;
      allowed-users = [ "@wheel" ];
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    registry.nixpkgs.flake = inputs.nixpkgs;
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
  boot.kernel.sysctl = {
    "kernel.sysrq" = 246;
  };
  console = {
    enable = true;
    earlySetup = true;
    packages = [ pkgs.terminus_font ];
    # ter-v16n for 1080p below
    # ter-v24n for 1080p
    # ter-v32n for 2K/4K
    font = lib.mkDefault "ter-v32n";
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
  networking.firewall = {
    allowedUDPPortRanges = [
      {
        from = 7400;
        to = 7500;
      }
      # DDS 默认发现端口 allow multi-cast
    ];
    extraCommands = ''
      # --- IPv4 组播规则 ---
      iptables -A nixos-fw -d 224.0.0.0/4 -p udp -j nixos-fw-accept
      iptables -A nixos-fw -p igmp -j nixos-fw-accept

      # --- IPv6 组播规则 (可选，如果你需要 IPv6 通信) ---
      ip6tables -A nixos-fw -d ff00::/8 -p udp -j nixos-fw-accept
    '';
    # 如果 ROS (Robot Operating System) 连不上机器人，可能需要在装了 ROS 的机器上启用这个
    # checkReversePath = false;
  };
  networking.networkmanager = {
    enable = true;
    dns = "default";
  };
  networking.nameservers = [
    "172.64.36.2"
    "149.112.112.11"
  ];
  services.chrony = {
    enable = true;
    servers = [ ];
    extraConfig = ''
      driftfile /var/lib/chrony/chrony.drift

      server time.grapheneos.org iburst
      server time.cloudflare.com iburst nts
      server nts.netnod.se iburst nts
      server 129.6.15.27 iburst

      makestep 1.0 3
      ntsdumpdir /var/lib/chrony
    '';
  };
  #SMART monitor
  services.smartd = {
    enable = lib.mkDefault true;
    defaults.monitored = "-a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,55,65";
  };
  users.users.root.shell = pkgs.zsh;
  users.users.${config.mainUser} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${config.mainUser}";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
  programs.zsh.enable = true;
  programs.nh.enable = true;
  programs.nix-ld.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
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
      init = {
        defaultBranch = "main";
      };
      url = {
        "ssh://git@github.com/" = {
          pushInsteadOf = [ "https://github.com/" ];
        };
      };
    };
  };
  environment.systemPackages = [
    pkgs.wget
    pkgs.curl
    pkgs.unar
    pkgs._7zz
    pkgs.tmux
    pkgs.python3Minimal
    pkgs.neovim
    # net utils
    pkgs.lsof
    pkgs.iputils
    pkgs.dnsutils
    pkgs.nettools
    #hardware
    pkgs.lshw
    pkgs.file
    pkgs.usbutils
    # modern tools
    pkgs.fzf
    pkgs.bat
    pkgs.gdu
    pkgs.btop
    pkgs.yazi
    pkgs.atuin
    pkgs.zoxide
    pkgs.chezmoi
    pkgs.lazygit
    pkgs.ripgrep
    pkgs.starship
    pkgs.attic-client
    # nix utils
    pkgs.nix-tree
    pkgs.nix-output-monitor
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    # x86_64 specific tools
    pkgs.sbctl
    pkgs.efibootmgr
    pkgs.mokutil
    pkgs.pciutils
  ];
}
