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
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
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
        # "https://ros.cachix.org"
        "https://attic.xuyh0120.win/lantian"
      ];
      trusted-public-keys = [
        "cachix:eBckug6/bGXXnIC+i6fms40KxCbstV+wJYV4JMwAvZ4="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        # "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
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
      options = "--delete-older-than 14d";
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
  networking.nameservers = lib.mkDefault [
    "172.64.36.2"
    "149.112.112.11"
  ];

  users.users.unbound.uid = lib.mkDefault 977;
  services.unbound = {
    enable = lib.mkDefault true;
    package = pkgs.unbound.override {
      openssl = pkgs.libressl;
      stdenv = pkgs.clangStdenv;
    };
    settings = {
      server = {
        interface = lib.mkDefault [
          "127.0.0.1"
          "::1"
        ];
        access-control = lib.mkDefault [
          "0.0.0.0/0 refuse"
          "127.0.0.0/8 allow"
          "::0/0 refuse"
          "::1 allow"
        ];

        do-ip4 = lib.mkDefault true;
        do-ip6 = lib.mkDefault false;
        do-udp = lib.mkDefault true;
        do-tcp = lib.mkDefault true;

        hide-identity = lib.mkDefault true;
        hide-version = lib.mkDefault true;
        hide-trustanchor = lib.mkDefault true;
        val-clean-additional = lib.mkDefault true;

        auto-trust-anchor-file = lib.mkDefault "/var/lib/unbound/root.key";
        val-log-level = lib.mkDefault 2;
        aggressive-nsec = lib.mkDefault true;

        edns-buffer-size = lib.mkDefault 1232;
        cache-min-ttl = lib.mkDefault 300;
        cache-max-ttl = lib.mkDefault 86400;
        prefetch = lib.mkDefault true;
        prefetch-key = lib.mkDefault true;
        serve-expired = lib.mkDefault true;
        serve-expired-ttl = lib.mkDefault 3600;

        so-reuseport = lib.mkDefault true;
        so-rcvbuf = lib.mkDefault "4m";
        so-sndbuf = lib.mkDefault "4m";
        outgoing-range = lib.mkDefault 8192;
        num-queries-per-thread = lib.mkDefault 4096;

        msg-cache-size = lib.mkDefault "50m";
        rrset-cache-size = lib.mkDefault "100m";
      };
    };
  };
  services.chrony = {
    package = pkgs.pkgsMusl.chrony;
    enable = true;
    servers = [ ];
    enableMemoryLocking = false;
    extraConfig = ''
      server time.grapheneos.org iburst
      server time.cloudflare.com iburst nts
      server nts.netnod.se iburst nts
      server 129.6.15.27 iburst

      noclientlog
      makestep 1.0 3
      ntsdumpdir /var/lib/chrony
      driftfile /var/lib/chrony/chrony.drift
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
    package = pkgs.openssh.override { openssl = pkgs.libressl; };
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

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
  };

  environment.systemPackages = [
    pkgs.pkgsMusl.wget
    pkgs.curl
    pkgs.unar
    pkgs._7zz
    pkgs.tmux
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
    pkgs.nawk
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
    (lib.hiPrio pkgs.uutils-coreutils-noprefix)
    (lib.mkIf config.programs.zsh.enable (pkgs.sqlite))
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    # x86_64 specific tools
    pkgs.sbctl
    pkgs.efibootmgr
    pkgs.mokutil
    pkgs.pciutils
  ];
  environment.shellAliases = {
    awk = "${pkgs.nawk}/bin/nawk";
  };
}
