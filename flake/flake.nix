{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    adlist = {
      url =
        "https://cdn.jsdelivr.net/gh/hydroakri/dnscrypt-proxy-blocklist@release/blocklist.txt";
      flake = false;
    };
    geodb = {
      url = "github:Loyalsoldier/v2ray-rules-dat/release";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, sops-nix, home-manager, adlist, geodb, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      zeroTrust = "ZEROTRUST";

      baseConfig = { config, pkgs, ... }: {
        nix.settings = {
          auto-optimise-store = true;
          experimental-features = [ "nix-command" "flakes" ];
          substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
        };
        nixpkgs.config.allowUnfree = true;
        nix.optimise.automatic = true;
        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
        # CPU microcode (common)
        hardware.cpu.amd.updateMicrocode = true;
        hardware.cpu.intel.updateMicrocode = true;
        boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
        boot.kernelParams = lib.mkDefault [
          # performance
          "lru_gen_enabled=1"
          "zswap.enabled=0"
          "transparent_hugepage=madvise"
          # security
          "processor.ignore_ppc=1"
          "mitigations=auto"
          "random.trust_cpu=0"
          "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
          "lockdown=integrity"
        ];
        boot.kernel.sysctl = lib.mkDefault {
          # Security (common)
          "kernel.core_pattern" = "|/bin/false";
          "kernel.unprivileged_bpf_disabled" = 1;
          "module.sig_enforce" = 1;
          "kernel.printk_devkmsg" = "off";

          # Network (common)
          "net.core.default_qdisc" = "cake";
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.ipv4.tcp_low_latency" = 1;
          "net.ipv4.tcp_timestamps" = 0;
          "net.ipv4.tcp_fastopen" = 3;
          "net.core.somaxconn" = 4096;
          "net.core.netdev_max_backlog" = 2048;
          "net.core.rmem_default" = 262144;
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_default" = 262144;
          "net.core.wmem_max" = 16777216;
          "net.core.optmem_max" = 65536;
          "net.ipv4.tcp_rmem" = "4096 87380 16777216";
          "net.ipv4.tcp_wmem" = "4096 65536 16777216";
          "net.ipv4.udp_rmem_min" = 8192;
          "net.ipv4.udp_wmem_min" = 8192;
          "net.ipv4.tcp_max_syn_backlog" = 8192;
          "net.ipv4.tcp_max_tw_buckets" = 2000000;
          "net.ipv4.tcp_tw_reuse" = 1;
          "net.ipv4.tcp_fin_timeout" = 20;
          "net.ipv4.tcp_slow_start_after_idle" = 0;
          "net.ipv4.tcp_keepalive_time" = 60;
          "net.ipv4.tcp_keepalive_intvl" = 10;
          "net.ipv4.tcp_keepalive_probes" = 6;
          "net.ipv4.tcp_mtu_probing" = 1;
          "net.ipv4.tcp_sack" = 1;
          "net.netfilter.nf_conntrack_max" = 1048576;
          "net.netfilter.nf_conntrack_tcp_timeout_established" = 120;

          # VM (common)
          "vm.page-cluster" = 0;
          "vm.nr_hugepages" = 0;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.dirty_expire_centisecs" = 1500;
          "vm.min_free_kbytes" = 65536;
          "vm.max_map_count" = 262144;
        };
        services.udev.extraRules = ''
          # NVMe SSD: 设置为 none
          ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

          # SATA SSD / eMMC: 设置为 mq-deadline
          ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

          # 旋转硬盘 HDD: 设置为 bfq
          ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
        '';
        services.zram-generator = {
          enable = true;
          settings = {
            "zram0" = {
              "zram-size" = "ram/2";
              "compression-algorithm" = "zstd";
            };
          };
        };
        security = {
          sudo-rs.enable = true;
          sudo.enable = false;
        };
        services.openssh.enable = true;
        services.fwupd.enable = true;
        services.fstrim.enable = true;
        services.btrfs.autoScrub = {
          enable = true;
          interval = "monthly";
          fileSystems = [ "/" ];
        };
        services.earlyoom.enable = true;
        systemd.oomd.enable = false;
        security.apparmor.enable = true;
        networking.firewall = {
          enable = true;
          allowedTCPPorts = [ 22 ];
          backend = "firewalld";
          package = pkgs.firewalld;
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
        systemd = {
          services.btrfs-balance = {
            description = "Smart Btrfs balance";
            requires = [ "local-fs.target" ];
            after = [ "local-fs.target" ];
            serviceConfig = {
              Type = "oneshot";
              ConditionACPower = true;
              ExecStart = pkgs.writeShellScript "smart-balance" ''
                set -e
                echo "Starting smart Btrfs balance..."
                ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=0 -musage=0 / || true
                ${pkgs.btrfs-progs}/bin/btrfs balance start -musage=30 / || true
                ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=10 / || true
                echo "Balance complete. SSD remains happy."
              '';
            };
          };
          timers.btrfs-balance = {
            description = "Run smart btrfs balance monthly";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "monthly";
              Persistent = true;
              RandomizedDelaySec = "1h";
            };
          };
        };
        environment.systemPackages = with pkgs; [
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
          mokutil
          chezmoi
          lazygit
          ripgrep
          nix-tree
          starship
          pciutils
          fastfetch
          efibootmgr
          ssh-to-age
        ];
        system.stateVersion = "25.11"; # Did you read the comment?
      };

      commonDesktopConfig = { config, pkgs, ... }: {
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.limine = {
          enable = true;
          biosDevice = "nodev";
          efiSupport = true;
          secureBoot.enable = true;
          secureBoot.sbctl = pkgs.sbctl;
          extraConfig = ''
            timeout: no
          '';
          extraEntries = ''
            /Windows
                protocol: efi
                path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
          '';
        };
        # Desktop scheduler (preempt for low latency)
        services.scx = {
          enable = true;
          scheduler = "scx_lavd";
          extraArgs = [ "--autopower" ];
        };
        boot.kernelPackages = pkgs.linuxPackages_xanmod;
        boot.kernelParams = [
          # battery
          "mem_sleep_default=s2idle"
          "iwlwifi.power_save=1"
          # boot screen
          "quiet"
          "splash"
          "loglevel=3"
          "rd.udev.log_level=3"
          "vt.global_cursor_default=0"
          "rd.systemd.show_status=auto"
          #performance
          "preempt=full"
          "mitigations=off"
          "nowatchdog"
          "nmi_watchdog=0"
          "radeon.dpm=1"
          "amd_pstate=active"
          "intel_pstate=active"
          "nouveau.config=NvGspRm=1"
          "nouveau.config=NvBoost=2"
          "nouveau.modeset=1"
        ];
        powerManagement.cpuFreqGovernor =
          "powersave"; # active 模式下 powersave 实际上是将控制权交给固件
        boot.kernel.sysctl = {
          # Desktop-specific VM tuning
          "vm.swappiness" = 180;
          "vm.dirty_ratio" = 10;
          "vm.dirty_background_ratio" = 5;
          # Desktop-specific scheduler tuning (low latency)
          "kernel.nmi_watchdog" = 0;
          "vm.laptop_mode" = 5;
          "net.ipv4.tcp_congestion_control" = "bbr3";
        };
        boot.consoleLogLevel = 3;
        boot.initrd.verbose = false;
        boot.plymouth.enable = true;
        services.udev.extraRules = ''
          # 电源控制
          SUBSYSTEM=="pci", ATTR{power/control}="auto"
        '';
        # services.auto-cpufreq.enable = true;
        services.power-profiles-daemon.enable = true;
        services.ananicy = {
          enable = true;
          package = pkgs.ananicy-cpp;
          rulesProvider = pkgs.ananicy-rules-cachyos;
        };
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;
          autoPrune = {
            enable = true;
            dates = "weekly";
            flags = [ "--all" ];
          };
        };
        programs.gamemode.enable = true;
        environment.systemPackages = with pkgs; [
          ## fancontrol
          nbfc-linux

          ## GPU / display tools
          nvtopPackages.full
          virtualglLib
          vulkan-tools
          libva-utils
          vdpauinfo
          read-edid
          clinfo

          ## CLI / user tools
          distrobox
        ];
        networking.interfaces.wlo1.wakeOnLan.enable = false;
        networking.interfaces.eno1.wakeOnLan.enable = false;
        networking.networkmanager = {
          enable = true;
          wifi.powersave = true;
        };
        fonts.fontDir = {
          enable = true;
          decompressFonts = true;
        };

        time.timeZone = "Australia/Perth";
        i18n = {
          defaultLocale = "zh_CN.UTF-8";
          extraLocales = [ "en_AU.UTF-8/UTF-8" ];
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
          inputMethod = {
            type = "fcitx5";
            enable = true;
            fcitx5 = {
              addons = with pkgs; [
                fcitx5-rime
                libsForQt5.fcitx5-qt
                fcitx5-gtk
                qt6Packages.fcitx5-configtool
                qt6Packages.fcitx5-chinese-addons
                fcitx5-lua
              ];
              waylandFrontend = true;
            };
          };
        };

        # X Server and input
        services.xserver.enable = true;
        services.libinput.enable = true;
        services.xserver.xkb = {
          layout = "us";
          variant = "";
        };

        # Desktop portal
        xdg.portal = {
          enable = true;
          xdgOpenUsePortal = true;
          extraPortals = [
            pkgs.xdg-desktop-portal-cosmic
            # pkgs.xdg-desktop-portal-gtk # niri
            # pkgs.xdg-desktop-portal-gnome # niri
          ];
        };

        # Polkit (privilege elevation)
        security.polkit.enable = true;
        security.pam.services.polkit.enable = true;
        systemd.user.services.polkit-agent = {
          description = "polkit-agent";
          wantedBy = [ "graphical-session.target" ];
          wants = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart =
              "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            # ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };

        # Secret service (keyring)
        services.gnome.gnome-keyring.enable = true;
        services.passSecretService.enable = true;
        security.pam.services.login.enableGnomeKeyring = true;

        # Printing
        services.printing.enable = true;

        # Audio (PipeWire)
        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        # nbfc-linux fancontrol
        systemd.services.nbfc_service = {
          enable = true;
          description = "NoteBook FanControl service";
          serviceConfig.Type = "simple";
          path = [ pkgs.kmod ];
          script =
            "${pkgs.nbfc-linux}/bin/nbfc_service -c /etc/nixos/nbfc.json";
          wantedBy = [ "multi-user.target" ];
        };

        # Bluetooth
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
          settings = {
            General = {
              Experimental = true;
              FastConnectable = true;
            };
            Policy = { AutoEnable = true; };
          };
        };

        # Graphics support (base configuration)
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
          extraPackages = with pkgs; [
            ## Scheduling layer
            vulkan-loader # Vulkan
            libglvnd # OpenGL
            ocl-icd # OpenCL

            ## drivers
            # amdvlk

            ## LIBs & Layer driver
            libva
            libvdpau
            libvdpau-va-gl
            libva-vdpau-driver
          ];
          extraPackages32 = with pkgs; [
            ## Scheduling layer
            vulkan-loader # Vulkan
            libglvnd # OpenGL
            ocl-icd # OpenCL

            ## drivers
            # driversi686Linux.amdvlk

            ## LIBs & Layer driver
            libva
            libvdpau
            driversi686Linux.libva-vdpau-driver
            driversi686Linux.libvdpau-va-gl
          ];
        };
        # Flatpak
        services.flatpak.enable = true;

        # Desktop firewall (includes gaming ports)
        networking.firewall = {
          allowedTCPPorts =
            [ 53 80 443 1080 5222 25565 27015 27036 27037 27040 53317 ];
          allowedUDPPorts = [ 1080 7777 27015 27031 27036 53317 ];
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
        services.dae = {
          enable = true;
          # configFile = "/etc/dae/config.dae";
          assetsPath = toString (pkgs.symlinkJoin {
            name = "dae-assets";
            paths = [ "${inputs.geodb}" ];
          });
          config = ''
            global {
              dial_mode: domain
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
                proxy {
                    policy: min_moving_avg
                }
            }

            routing {
              pname(NetworkManager, dnscrypt-proxy, nekoray, nekobox_core, verge-mihomo, clash-verge, clash-verge-service) -> must_direct
              dip(224.0.0.0/3, 'ff00::/8', geoip:private) -> must_direct

              dip(geoip:cn) -> direct 
              ip(geoip:cn) -> direct 
              domain(geosite:cn, geosite:geolocation-cn, geosite:china-list, geosite:apple-cn, geosite:google-cn) -> direct

              domain(geosite:gfw) -> proxy

              fallback: proxy
            }
          '';
        };
        services.dnscrypt-proxy = {
          enable = true;
          configFile = config.sops.templates."dnscrypt-proxy.toml".path;
          settings = {
            cache = true;
            cache_size = 4096;
            block_ipv6 = true;
            netprobe_timeout = 300;
            lb_strategy = "p2";
            blocked_names.blocked_names_file =
              pkgs.writeText "blocklist.txt" (builtins.readFile inputs.adlist);
            ipv4_servers = true;
            ipv6_servers = false;
            dnscrypt_servers = true;
            doh_servers = true;
            odoh_servers = true;
            require_dnssec = false;
            require_nolog = false;
            require_nofilter = false;
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
              "quad101"
              "flymc-doh-8443"
              "flymc-doh"
              "zerotrust"
            ];
            static.flymc-doh-8443.stamp =
              "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyABFkbnMuZmx5bWMuY2M6ODQ0MwovZG5zLXF1ZXJ5";
            static.flymc-doh.stamp =
              "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyAAxkbnMuZmx5bWMuY2MKL2Rucy1xdWVyeQ";
            static.zerotrust.stamp = zeroTrust;
            sources.public-resolvers = {
              urls = [
                "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
                "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
              ];
              cache_file = "public-resolvers.md";
              minisign_key =
                "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
              refresh_delay = 72;
            };
          };
        };
        sops = {
          defaultSopsFile = ./secrets.yaml;
          defaultSopsFormat = "yaml";
          age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          secrets.doh_stamp = { };
          templates."dnscrypt-proxy.toml" = {
            mode = "0444";
            content = builtins.replaceStrings [ zeroTrust ]
              [ config.sops.placeholder.doh_stamp ] (builtins.readFile
                (pkgs.runCommand "to-toml" {
                  nativeBuildInputs = [ pkgs.yj ];
                } ''
                  echo '${
                    builtins.toJSON config.services.dnscrypt-proxy.settings
                  }' | yj -jt > $out
                ''));
          };
        };
      };

      # Common server configuration
      commonServerConfig = { config, pkgs, ... }: {
        boot.kernelPackages = pkgs.linuxPackages;
        boot.kernelParams = [ "preempt=voluntary" ];
        boot.kernel.sysctl = {
          "vm.swappiness" = 10;
          "vm.dirty_ratio" = 40;
          "vm.dirty_background_ratio" = 10;
        };
        services.irqbalance.enable = true;
        services.tuned.enable = true;
        services.tuned.profile = "throughput-performance";
        services.fail2ban.enable = true;
      };

      # Desktop hosts
      desktopHosts = {
        "omen15" = { config, pkgs, ... }: {
          imports = [
            ./omen15.nix
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.hydroakri = import ./hydroakri.nix;
            }
          ];
          networking.hostName = "omen15";
          boot = {
            initrd.kernelModules = [ "amdgpu" ];
            kernelModules = [ "zenpower" ];
            blacklistedKernelModules = [ "k10temp" ];
            extraModulePackages = [ config.boot.kernelPackages.zenpower ];
            extraModprobeConfig = ''
              options snd_hda_intel power_save=1
            '';
          };
          services.displayManager = {
            sddm.enable = true;
            # gdm.enable = true;
            # cosmic-greeter.enable = true;
          };
          services.desktopManager = {
            cosmic = {
              enable = true;
              xwayland.enable = true;
            };
            # gnome.enable = true;
            plasma6.enable = true;
          };
          services.xserver.desktopManager.xfce = {
            enable = false;
            enableWaylandSession = true;
          };

          environment.etc."nixos/nbfc.json".text =
            builtins.toJSON { SelectedConfigId = "HP OMEN Laptop 15-en0xxx"; };
          environment.systemPackages = with pkgs; [
            # file manager
            # xfce.thunar
            # xfce.thunar-archive-plugin
            # xarchiver
            # file-roller
            # file manager
            kdePackages.partitionmanager
            kdePackages.kpmcore

            # Wayland compositor
            xwayland-satellite
            # networkmanagerapplet
            brightnessctl
            pavucontrol
            playerctl
            # blueman
            # qt6ct
            # mako
            # waybar
            # xfce.xfconf
            # xfce.xfce4-panel
            # xfce.xfce4-panel-profiles
            # rofi

            yad # steamtinkerlaunch depend
            steam-devices-udev-rules
          ];
          environment.plasma6.excludePackages = (with pkgs; [
            kdePackages.elisa
            kdePackages.gwenview
            kdePackages.kwrited
          ]);
          environment.cosmic.excludePackages =
            (with pkgs; [ cosmic-player cosmic-term cosmic-edit ]);
          environment.gnome.excludePackages = (with pkgs; [
            atomix # puzzle game
            cheese # webcam tool
            epiphany # web browser
            evince # document viewer
            geary # email reader
            gedit # text editor
            gnome-characters
            gnome-music
            gnome-photos
            gnome-terminal
            gnome-tour
            hitori # sudoku game
            iagno # go game
            tali # poker game
            totem # video player
          ]);
          hardware.amdgpu.overdrive.enable = true;
          hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr.icd ];
          hardware.graphics.extraPackages32 = with pkgs;
            [ rocmPackages.clr.icd ];
          specialisation = {
            nvidia-variant.configuration = {
              system.nixos.tags = [ "nvidia" ];

              services.xserver.videoDrivers = [ "nvidia" ];
              boot.kernelParams =
                [ "nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" ];
              # Early KMS
              boot.initrd.kernelModules =
                [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
              boot.extraModprobeConfig = ''
                options nvidia-drm modeset=1
                options nvidia NVreg_EnableGpuFirmware=1
                options nvidia NVreg_PreserveVideoMemoryAllocations=1
                options nvidia NVreg_TemporaryFilePath=/var/tmp
              '';
              hardware.nvidia = {
                open = true;
                modesetting.enable = true;
                nvidiaPersistenced = false;
                videoAcceleration = true;
                dynamicBoost.enable = true;
                powerManagement = {
                  enable = true;
                  finegrained = true; # conflict with sync
                };
                prime = {
                  offload = {
                    enable = true; # conflict with sync
                    enableOffloadCmd = true; # like `prime-run`
                  };
                  sync.enable = false;
                  amdgpuBusId = "PCI:7@0:0:0";
                  nvidiaBusId = "PCI:1@0:0:0";
                };
              };
              environment.systemPackages = with pkgs;
                [ cudaPackages.cudatoolkit ];
              hardware.graphics = {
                enable = true;
                enable32Bit = true;
                extraPackages = with pkgs; [ nvidia-vaapi-driver ];
                extraPackages32 = with pkgs; [ nvidia-vaapi-driver ];
              };
            };
          };
          # Video drivers (hardware-specific)
          services.xserver.videoDrivers = [ "nouveau" "amdgpu" ];
          # User definition
          users.users.hydroakri = {
            shell = pkgs.zsh;
            isNormalUser = true;
            description = "hydroakri";
            extraGroups = [ "networkmanager" "wheel" "video" "gamemode" ];
          };
          programs.zsh.enable = true;
          # programs.niri.enable = true;
          programs = {
            gamescope = {
              enable = true;
              capSysNice = true;
            };
            steam = {
              enable = false;
              remotePlay.openFirewall = true;
              dedicatedServer.openFirewall = true;
              localNetworkGameTransfers.openFirewall = true;
              gamescopeSession.enable = true;
              extraCompatPackages = with pkgs; [ steamtinkerlaunch ];
            };
          };
          # Application-specific programs (host-specific)
          programs.throne.enable = true;
          programs.clash-verge = {
            enable = true;
            serviceMode = true;
            package = pkgs.clash-verge-rev;
          };
          # AMD GPU control (hardware-specific)
          services.lact.enable = true;
          services.sunshine = {
            enable = true;
            autoStart = true;
            capSysAdmin = true;
            openFirewall = true;
          };
        };
      };

      # Server hosts
      serverHosts = {
        "hostB" = { config, pkgs, ... }: {
          networking.hostName = "hostB";
          # hostB-specific adjustments
          services.httpd.enable = true;
          services.httpd.adminAddr = "admin@example.com";
        };
      };

      # Desktop NixOS configurations
      desktopConfigurations = lib.mapAttrs (hostName: hostOverrides:
        nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            baseConfig
            commonDesktopConfig
            hostOverrides
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
          ];
        }) desktopHosts;

      # Server NixOS configurations
      serverConfigurations = lib.mapAttrs (hostName: hostOverrides:
        nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            baseConfig
            commonServerConfig
            hostOverrides
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
          ];
        }) serverHosts;

    in {
      # NixOS system configurations by hostname (combined)
      nixosConfigurations = desktopConfigurations // serverConfigurations;
    };
}
