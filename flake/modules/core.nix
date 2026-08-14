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
    inputs.sops-nix.nixosModules.sops
  ];

  options.modules.core = {
    extraSubstituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional binary cache substituters appended after cache.nixos.org";
      # 参考备用源:
      # "https://mirrors.ustc.edu.cn/nix-channels/store"
      # "https://ros.cachix.org"
    };
    extraTrustedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Trusted public keys for extra binary caches";
      # "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
    };
  };

  config = {

    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    hardware.enableRedistributableFirmware = lib.mkDefault true;
    nixpkgs.config.allowUnfree = lib.mkDefault true;
    nix = {
      package = pkgs.lix;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ]
        ++ config.modules.core.extraSubstituters;
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ]
        ++ config.modules.core.extraTrustedPublicKeys;
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
      "kernel.sysrq" = lib.mkOverride 950 246;
    };
    console = {
      enable = lib.mkDefault true;
      earlySetup = lib.mkDefault true;
      packages = [ pkgs.terminus_font ];
      # ter-v16n for 1080p below
      # ter-v24n for 1080p
      # ter-v32n for 2K/4K
      font = lib.mkDefault "ter-v32n";
    };
    time.timeZone = lib.mkDefault "UTC";
    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [ "en_US.UTF-8/UTF-8" ];
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
      enable = lib.mkDefault true;
      dns = lib.mkDefault "default";
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
        withSystemd = true;
      };
      settings = {
        server = {
          interface = lib.mkDefault [
            "0.0.0.0"
            "::"
          ];
          # 未匹配的来源默认拒绝,不用另写 refuse
          access-control = lib.mkDefault [
            "10.0.0.0/8 allow"
            "172.16.0.0/12 allow"
            "192.168.0.0/16 allow"
            "fd00::/8 allow"
            "127.0.0.0/8 allow"
            "::1/128 allow"
          ];

          do-ip4 = lib.mkDefault true;
          do-ip6 = lib.mkDefault true;
          do-udp = lib.mkDefault true;
          do-tcp = lib.mkDefault true;

          hide-identity = lib.mkDefault true;
          hide-version = lib.mkDefault true;
          hide-trustanchor = lib.mkDefault true;
          val-clean-additional = lib.mkDefault true;
          harden-large-queries = lib.mkDefault true;
          use-caps-for-id = lib.mkDefault true;

          auto-trust-anchor-file = lib.mkDefault "/var/lib/unbound/root.key";
          val-log-level = lib.mkDefault 2;
          aggressive-nsec = lib.mkDefault true;

          # DNS rebinding protection: refuse external answers resolving into LAN/link-local ranges.
          private-address = lib.mkDefault [
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "169.254.0.0/16"
            "fd00::/8"
            "fe80::/10"
            "127.0.0.0/8"
            "::1/128"
            "::ffff:0:0/96"
          ];

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

          module-config = lib.mkDefault ''"respip validator iterator"'';
        };
      };
    };

    users = {
      users.dnscrypt-proxy = {
        isSystemUser = true;
        group = "dnscrypt-proxy";
        uid = lib.mkDefault 970;
      };
      groups.dnscrypt-proxy = { };
    };
    systemd.services.dnscrypt-proxy.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "dnscrypt-proxy";
      Group = "dnscrypt-proxy";
    };
    services.dnscrypt-proxy = {
      enable = lib.mkDefault true;
      package = pkgs.pkgsMusl.dnscrypt-proxy;
      settings = {
        listen_addresses = [ "127.0.0.1:5353" ];
        bootstrap_resolvers = [
          "9.9.9.9:53"
          "1.1.1.1:53"
        ];
        block_ipv6 = true;
        cache = true;
        cache_size = 4096;
        dnscrypt_servers = true;
        doh_servers = true;
        ipv4_servers = true;
        ipv6_servers = false;
        lb_strategy = "p2";
        netprobe_timeout = 300;
        odoh_servers = true;
        require_dnssec = false;
        require_nofilter = false;
        require_nolog = false;
        server_names = [
          "cloudflare"
          "cloudflare-security"
          "mullvad-adblock-doh"
          "mullvad-all-doh"
          "mullvad-base-doh"
          "mullvad-doh"
          "mullvad-extend-doh"
          "nextdns"
          "nextdns-ultralow"
          "controld-block-malware"
          "controld-block-malware-ad"
          "controld-block-malware-ad-social"
          "controld-uncensored"
          "controld-unfiltered"
          "dns0"
          "dns0-unfiltered"
          "adguard-dns-doh"
          "adguard-dns-unfiltered-doh"
          "quad9-dnscrypt-ip4-filter-ecs-pri"
          "quad9-dnscrypt-ip4-filter-pri"
          "quad9-dnscrypt-ip4-nofilter-ecs-pri"
          "quad9-dnscrypt-ip4-nofilter-pri"
          "quad9-doh-ip4-port443-filter-ecs-pri"
          "quad9-doh-ip4-port443-filter-pri"
          "quad9-doh-ip4-port443-nofilter-ecs-pri"
          "quad9-doh-ip4-port443-nofilter-pri"
          "quad9-doh-ip4-port5053-filter-ecs-pri"
          "quad9-doh-ip4-port5053-filter-pri"
          "quad9-doh-ip4-port5053-nofilter-ecs-pri"
          "quad9-doh-ip4-port5053-nofilter-pri"
          "rethinkdns-doh"
          "flymc-doh"
          "flymc-doh-8443"
        ];
        blocked_names.blocked_names_file = "${inputs.dnscrypt-blocklist}";
        monitoring_ui = {
          enabled = true;
          listen_address = "127.0.0.1:9007";
          prometheus_enabled = true;
          username = "";
          password = "";
        };
        sources.public-resolvers = {
          cache_file = "public-resolvers.md";
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          refresh_delay = 72;
          urls = [
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          ];
        };
        static = {
          flymc-doh.stamp = "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyAAxkbnMuZmx5bWMuY2MKL2Rucy1xdWVyeQ";
          flymc-doh-8443.stamp = "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyABFkbnMuZmx5bWMuY2M6ODQ0MwovZG5zLXF1ZXJ5";
        };
      };
    };

    services.chrony = {
      package = pkgs.pkgsMusl.chrony;
      enable = lib.mkDefault true;
      servers = [ ];
      enableMemoryLocking = lib.mkDefault false;
      # rtcsync（下方 extraConfig）与 enableRTCTrimming 二选一；选 rtcsync（每 11 分钟同步一次）
      enableRTCTrimming = lib.mkDefault false;
      extraFlags = lib.mkDefault [
        # 不加 "-F"：chronyd 内建 seccomp 白名单假设 glibc/glibc malloc，与本仓库的
        # musl + hardened_malloc 组合不兼容（触发白名单外系统调用，SIGSYS 崩溃）；
        # systemd 层的 SystemCallFilter（NixOS chrony 模块自带）已提供等价过滤。
        "-r" # 重启后复用 dumpdir 里存的历史测量数据,加快收敛
      ];
      extraConfig = ''
        server time.grapheneos.org iburst
        server time.cloudflare.com iburst nts
        server nts.netnod.se iburst nts
        server ntppool1.time.nl iburst nts
        server time.dfm.dk iburst nts
        server time.cifelli.xyz iburst nts
        server 129.6.15.27 iburst

        minsources 3
        authselectmode prefer
        dscp 46
        noclientlog
        makestep 1.0 3
        ntsdumpdir /var/lib/chrony
        driftfile /var/lib/chrony/chrony.drift
        dumpdir /var/lib/chrony
        rtcsync
        leapseclist ${pkgs.tzdata}/share/zoneinfo/leap-seconds.list
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
    programs.zsh.enable = lib.mkDefault true;
    programs.nh.enable = lib.mkDefault true;
    programs.nix-ld.enable = lib.mkDefault true;
    programs.direnv = {
      enable = lib.mkDefault true;
      nix-direnv.enable = lib.mkDefault true;
    };
    programs.nix-index-database.comma.enable = lib.mkDefault true;
    programs.ssh = {
      package = pkgs.openssh.override { openssl = pkgs.libressl; };
      startAgent = lib.mkDefault true;
      extraConfig = ''
        Host github.com
          # ProxyCommand nc -X connect -x 127.0.0.1:1080 %h %p
          ServerAliveInterval 10
          Hostname ssh.github.com
          Port 443
      '';
    };
    programs.git = {
      enable = lib.mkDefault true;
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
      enable = lib.mkDefault true;
      defaultEditor = lib.mkDefault true;
      viAlias = lib.mkDefault true;
      vimAlias = lib.mkDefault true;
      withNodeJs = lib.mkDefault true;
      withPython3 = lib.mkDefault true;
    };

    environment.systemPackages = [
      pkgs.pkgsMusl.wget
      pkgs.curl
      pkgs.unar
      pkgs._7zz
      # net utils
      pkgs.lsof
      pkgs.iputils
      pkgs.dnsutils
      pkgs.nettools
      #hardware
      pkgs.lshw
      pkgs.file
      pkgs.usbutils
      pkgs.chezmoi
      # nix utils
      pkgs.attic-client
      pkgs.nix-tree
      inputs.nix-alien.packages.${pkgs.stdenv.hostPlatform.system}.default
      # system-wide
      (lib.hiPrio pkgs.uutils-coreutils-noprefix)
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

  }; # end config
}
