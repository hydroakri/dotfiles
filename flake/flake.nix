{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    minegrub-theme.url = "github:Lxtharia/minegrub-theme";
  };

  outputs = { self, nixpkgs, home-manager, minegrub-theme, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Common NixOS configuration
      commonNixOSConfig = {
        nix.settings.substituters =
          [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
        # Bootloader.
        boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.grub = {
          device = "nodev";
          efiSupport = true;
          useOSProber = true;
        };
        boot.kernelParams = [
          "zswap.enabled=0"
          "processor.ignore_ppc=1"
          "mem_sleep_default=s2idle"
          "nowatchdog"
          "nmi_watchdog=0"
          "iwlwifi.power_save=1"
          "mitigations=auto"
          "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
          "lockdown=integrity"
          "quiet"
          "splash"
          "loglevel=3"
          "rd.udev.log_level=3"
          "vt.global_cursor_default=0"
          "rd.systemd.show_status=auto"
        ];
        boot.consoleLogLevel = 3;
        boot.initrd.verbose = false;
        boot.kernel.sysctl = {
          #security
          "kernel.core_pattern" = "|/bin/false";
          "kernel.unprivileged_bpf_disabled" = 0;
          "kernel.kptr_restrict" = 2;
          "kernel.yama.ptrace_scope" = 3;
          "kernel.kexec_load_disabled" = 1;
          "module.sig_enforce" = 1;
          "net.core.bpf_jit_harden" = 2;

          # performance;
          "net.core.default_qdisc" = "cake";
          "net.ipv4.tcp_congestion_control" = "bbr2";

          "net.core.somaxconn" = 256;
          "net.core.netdev_max_backlog" = 16384;
          "net.core.rmem_default" = 1048576;
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_default" = 1048576;
          "net.core.wmem_max" = 16777216;
          "net.core.optmem_max" = 65536;
          "net.ipv4.tcp_rmem" = "4096 1048576 2097152";
          "net.ipv4.tcp_wmem" = "4096 65536 16777216";
          "net.ipv4.udp_rmem_min" = 8192;
          "net.ipv4.udp_wmem_min" = 8192;
          "net.ipv4.tcp_fastopen" = 3;
          "net.ipv4.tcp_max_syn_backlog" = 8192;
          "net.ipv4.tcp_max_tw_buckets" = 2000000;
          "net.ipv4.tcp_tw_reuse" = 1;
          "net.ipv4.tcp_fin_timeout" = 10;
          "net.ipv4.tcp_slow_start_after_idle" = 0;
          "net.ipv4.tcp_keepalive_time" = 60;
          "net.ipv4.tcp_keepalive_intvl" = 10;
          "net.ipv4.tcp_keepalive_probes" = 6;
          "net.ipv4.tcp_mtu_probing" = 1;
          "net.ipv4.tcp_sack" = 1;

          "vm.swappiness" = 180;
          "vm.watermark_boost_factor" = 0;
          "vm.watermark_scale_factor" = 125;
          "vm.page-cluster" = 0;

          "vm.dirty_ratio" = 8;
          "vm.dirty_background_ratio" = 4;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.dirty_expire_centisecs" = 1500;
          "vm.laptop_mode" = 5;
          "vm.vfs_cache_pressure" = 50;
        };
        services.udev.extraRules = ''
          SUBSYSTEM=="pci", ATTR{power/control}="auto"
        '';
        zramSwap.enable = true;
        services.zram-generator.enable = true;
        services.zram-generator.settings.main = {
          name = "zram0";
          size = "ram/2";
          algorithm = "zstd";
        };
        services.fstrim.enable = true;
        services.preload.enable = true;
        services.earlyoom.enable = true;
        security.apparmor.enable = true;
        networking.networkmanager.enable = true;
        networking.firewall = {
          enable = true;
          allowedTCPPorts = [ 80 443 1080 27015 27036 27037 27040 53317 ];
          allowedUDPPorts = [ 1080 27015 27031 27036 53317 ];
          allowedUDPPortRanges = [
            {
              from = 27031;
              to = 27036;
            }
            {
              from = 8000;
              to = 8010;
            }
          ];
        };
        services.dnscrypt-proxy2 = {
          enable = true;
          settings = {
            block_ipv6 = true;
            lb_strategy = "p2";
            server_names = [
              "cloudflare"
              "cloudflare-family"
              "cloudflare-security"
              "mullvad-adblock-doh"
              "mullvad-all-doh"
              "mullvad-base-doh"
              "mullvad-doh"
              "mullvad-extend-doh"
              "mullvad-family-doh"
              "nextdns"
              "nextdns-ultralow"
              "controld-block-malware"
              "controld-block-malware-ad"
              "controld-block-malware-ad-social"
              "controld-family-friendly"
              "controld-uncensored"
              "controld-unfiltered"
              "dns0"
              "dns0-kid"
              "dns0-unfiltered"
              "adguard-dns-doh"
              "adguard-dns-family-doh"
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
              "flymc-doh-8443"
              "flymc-doh"
              "flymc-doh-cdn"
              "flymc-dns"
            ];
            static.flymc-doh-8443.stamp =
              "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyABFkbnMuZmx5bWMuY2M6ODQ0MwovZG5zLXF1ZXJ5";
            static.flymc-doh.stamp =
              "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyAAxkbnMuZmx5bWMuY2MKL2Rucy1xdWVyeQ";
            static.flymc-doh-cdn.stamp =
              "sdns://AgQAAAAAAAAADDEwNC4yMS40Ni4xOAAQZG9oLnBhcmkubmV0d29yawovZG5zLXF1ZXJ5";
            static.flymc-dns.stamp =
              "sdns://AgQAAAAAAAAADjE3Mi42Ny4yMjIuMTM5ABBkbnMucGFyaS5uZXR3b3JrCi9kbnMtcXVlcnk";
            sources.public-resolvers = {
              urls = [
                "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
              ];
              cache_file = "public-resolvers.md";
              minisign_key =
                "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
              refresh_delay = 72;
            };
          };
        };
        services.ntp.enable = true;
        services.ntp.servers =
          [ "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" ];
        time.timeZone = "Australia/Perth";
        # cuz of non-FHS need to export fonts dir to let normal app to read
        fonts.fontDir.enable = true;
        i18n = {
          defaultLocale = "en_AU.UTF-8";
          extraLocales = [ "zh_CN.UTF-8/UTF-8" ];
          extraLocaleSettings = {
            LC_ADDRESS = "en_AU.UTF-8";
            LC_IDENTIFICATION = "en_AU.UTF-8";
            LC_MEASUREMENT = "en_AU.UTF-8";
            LC_MONETARY = "en_AU.UTF-8";
            LC_NAME = "en_AU.UTF-8";
            LC_NUMERIC = "en_AU.UTF-8";
            LC_PAPER = "en_AU.UTF-8";
            LC_TELEPHONE = "en_AU.UTF-8";
            LC_TIME = "en_AU.UTF-8";
          };
        };
        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
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
        environment.etc."proxychains.conf".text = ''
          strict_chain
          proxy_dns
          quiet_mode
          remote_dns_subnet 224
          tcp_read_time_out 15000
          tcp_connect_time_out 8000
          localnet 127.0.0.0/255.0.0.0

          [ProxyList]
          socks5 127.0.0.1 1080
        '';
        environment.shellAliases = { vi = "nvim"; };
        environment.systemPackages = with pkgs; [
          xz
          zip
          gcc
          fzf
          bat
          fish
          btop
          ncdu
          wget
          lsof
          yazi
          atuin
          unzip
          p7zip
          cargo
          zoxide
          neovim
          lazygit
          chezmoi
          ripgrep
          pciutils
          starship
          fastfetch
          efibootmgr
          proxychains-ng
          (let base = pkgs.appimageTools.defaultFhsEnvArgs;
          in pkgs.buildFHSEnv (base // {
            name = "fhs";
            targetPkgs = pkgs:
              # pkgs.appimageTools 提供了大多数程序常用的基础包，所以我们可以直接用它来补充
              (base.targetPkgs pkgs) ++ (with pkgs; [ pkg-config ncurses ]);
            profile = "export FHS=1";
            runScript = "bash";
            extraOutputsToInstall = [ "dev" ];
          }))
        ];
        # nixpkgs.config.allowUnfree = true;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        system.stateVersion = "25.05"; # Did you read the comment?
      };

      # Host-specific overrides
      hosts = {
        "omen15" = {
          imports = [
            minegrub-theme.nixosModules.default
            ./omen15.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.hydroakri = import ./hydroakri.nix;
            }
          ];
          networking.hostName = "omen15";
          boot.loader.grub.minegrub-theme = {
            enable = true;
            splash = "Never Knows Best";
            background = "background_options/1.8  - [Classic Minecraft].png";
            boot-options-count = 4;
          };
          boot.plymouth.enable = true;
          boot.kernelParams = [
            "radeon.dpm=1"
            "amd_pstate=active"
            "nvidia_drm.modeset=1"
            "nvidia_drm.fbdev=1"
            "nouveau.config=NvGspRm=1"
            "nouveau.config=NvBoost=2"
          ];
          # Early KMS
          boot.initrd.kernelModules =
            [ "amdgpu" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
          boot.extraModprobeConfig = ''
            options nvidia-drm modeset=1
            options nvidia NVreg_PreserveVideoMemoryAllocations=1
          '';
          i18n.inputMethod = {
            type = "fcitx5";
            enable = true;
            fcitx5 = {
              plasma6Support = true;
              addons = with pkgs; [
                fcitx5-rime
                libsForQt5.fcitx5-qt
                fcitx5-gtk
                fcitx5-configtool
                fcitx5-chinese-addons
                fcitx5-lua
              ];
              waylandFrontend = true;
            };
          };
          # Desktop needs
          services.xserver.enable = true;
          services.libinput.enable = true;
          services.displayManager.sddm.enable = true;
          services.desktopManager.plasma6.enable = true;
          services.xserver.xkb = {
            layout = "us";
            variant = "";
          };
          services.printing.enable = true;
          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
          };
          services.dae = {
            enable = true;
            # configFile = "/etc/dae/config.dae";
            config = ''
              global {
                dial_mode: domain+
                lan_interface: auto
                wan_interface: auto
                log_level: info
                auto_config_kernel_parameter: true
                tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1,2606:4700:4700::1111'
                tcp_check_http_method: HEAD
                check_interval: 30s
                check_tolerance: 50ms
              }

              node {
                  'socks5://localhost:1080'
              }

              dns {
                upstream {
                  alih3: 'h3://dns.alidns.com:443/dns-query'
                  localdns: 'udp://127.0.0.1:53'
                }
                routing {
                  request {
                    qname(geosite:cn) -> alih3
                    fallback: localdns
                  }
                }
              }

              group {
                  local_proxy {
                      policy: min_moving_avg
                  }
              }

              routing {
                pname(NetworkManager) -> direct
                dip(224.0.0.0/3, 'ff00::/8') -> direct
                pname(dnscrypt-proxy) -> must_direct
                pname(nekoray) -> must_direct
                pname(nekobox_core) -> must_direct

                dip(geoip:private) -> direct
                dip(geoip:cn) -> direct
                ip(geoip:cn) -> direct
                domain(geosite:cn) -> direct
                domain(geosite:category-ads) -> block

                fallback: local_proxy
              }
            '';
          };
          environment.systemPackages = with pkgs; [
            xsettingsd
            xorg.xrdb
            steam-devices-udev-rules
            daed
          ];
          # GPU
          hardware.nvidia.open = true;
          hardware.nvidia.modesetting.enable = true;
          hardware.nvidia.nvidiaPersistenced = true;
          services.xserver.videoDrivers = [ "nvidia" ];
          # User defination
          users.users.hydroakri = {
            shell = pkgs.fish;
            isNormalUser = true;
            description = "hydroakri";
            extraGroups = [ "networkmanager" "wheel" ];
          };
          programs.fish.enable = true;
          services.displayManager.autoLogin.enable = true;
          services.displayManager.autoLogin.user = "hydroakri";
          services.flatpak.enable = true;
        };
        "hostB" = {
          networking.hostName = "hostB";
          # hostB-specific adjustments
          services.httpd.enable = true;
          services.httpd.adminAddr = "admin@example.com";
        };
      };

    in {
      # NixOS system configurations by hostname
      nixosConfigurations = lib.mapAttrs (hostName: hostOverrides:
        nixpkgs.lib.nixosSystem {
          system = system;
          # combine common defaults and host-specific overrides as modules:
          modules = [
            commonNixOSConfig
            hostOverrides
            # you still need home-manager & hardware modules if used in hostOverrides:
            home-manager.nixosModules.home-manager
          ];
        }) hosts;
    };
}
