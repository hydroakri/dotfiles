{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
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

  outputs = { self, nixpkgs, home-manager, adlist, geodb, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Common NixOS configuration
      commonNixOSConfig = {
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
        # Bootloader.
        boot.kernelPackages = pkgs.linuxPackages_xanmod;
        hardware.cpu.amd.updateMicrocode = true;
        hardware.cpu.intel.updateMicrocode = true;
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
        boot.kernelParams = [
          "zswap.enabled=0"
          "processor.ignore_ppc=1"
          "mem_sleep_default=s2idle"
          "nowatchdog"
          "nmi_watchdog=0"
          "iwlwifi.power_save=1"
          "mitigations=auto"
          "random.trust_cpu=0"
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
          "kernel.unprivileged_bpf_disabled" = 1;
          "module.sig_enforce" = 1;

          # performance;
          "kernel.nmi_watchdog" = 0;
          "kernel.printk_devkmsg" = "off";
          "kernel.sched_autogroup_enabled" = 1; # 1 for desktop, 0 for server
          "kernel.sched_latency_ns" = 12000000; # 12 ms
          "kernel.sched_min_granularity_ns" = 1500000; # 1.5 ms
          "kernel.sched_wakeup_granularity_ns" = 2000000; # 2 ms

          "net.core.default_qdisc" = "cake";
          "net.ipv4.tcp_congestion_control" = "bbr3";

          "net.ipv4.tcp_low_latency" = 1;
          "net.ipv4.tcp_timestamps" = 0;
          "net.ipv4.tcp_fastopen" = 3;
          "net.core.somaxconn" = 4096;
          "net.core.netdev_max_backlog" = 2048;
          "net.core.rmem_default" = 1048576;
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_default" = 1048576;
          "net.core.wmem_max" = 16777216;
          "net.core.optmem_max" = 65536;
          "net.ipv4.tcp_rmem" = "4096 1048576 2097152";
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

          "vm.swappiness" = 180;
          "vm.page-cluster" = 0;

          "vm.laptop_mode" = 5;
          "vm.nr_hugepages" = 0;
          "vm.dirty_ratio" = 10;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_background_ratio" = 5;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.dirty_expire_centisecs" = 1500;
          "vm.min_free_kbytes" = 65536;
          "vm.max_map_count" = 262144;
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
        security = {
          sudo-rs.enable = true;
          sudo.enable = false;
        };
        services.fwupd.enable = true;
        services.fstrim.enable = true;
        services.preload.enable = true;
        services.earlyoom.enable = true;
        systemd.oomd.enable = false;
        # services.auto-cpufreq.enable = true;
        services.power-profiles-daemon.enable = true;
        programs.gamemode.enable = true;
        security.apparmor.enable = true;
        networking.interfaces.wlo1.wakeOnLan.enable = false;
        networking.interfaces.eno1.wakeOnLan.enable = false;
        networking.networkmanager = {
          enable = true;
          wifi.powersave = true;
        };
        networking.firewall = {
          enable = true;
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
        services.dnscrypt-proxy = {
          enable = true;
          settings = {
            cache = true;
            cache_size = 4096;
            block_ipv6 = true;
            netprobe_timeout = 300;
            lb_strategy = "p2";
            blocked_names.blocked_names_file = blocklist_txt;
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
            static.zerotrust.stamp = lib.strings.removeSuffix "\n"
              (builtins.readFile /etc/nixos/DOH_STAMP.txt);
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
        services.chrony = {
          enable = true;
          servers = [ "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" ];
        };
        time.timeZone = "Australia/Perth";
        # cuz of non-FHS need to export fonts dir to let normal app to read
        fonts.fontDir.enable = true;
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
        virtualisation.podman = {
          enable = true;
          dockerCompat = true;
          autoPrune = {
            enable = true;
            dates = "weekly";
            flags = [ "--all" ];
          };
        };
        environment.shellAliases = { vi = "nvim"; };
        environment.systemPackages = with pkgs; [
          xz
          zip
          fzf
          bat
          gdu
          fish
          btop
          wget
          lsof
          yazi
          atuin
          unzip
          p7zip
          zoxide
          neovim
          mokutil
          lazygit
          chezmoi
          ripgrep
          nix-tree
          pciutils
          starship
          distrobox
          fastfetch
          efibootmgr
          proxychains-ng
        ];
        system.stateVersion = "25.11"; # Did you read the comment?
      };

      # Host-specific overrides
      hosts = {
        "omen15" = {
          imports = [
            ./omen15.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.hydroakri = import ./hydroakri.nix;
            }
          ];
          networking.hostName = "omen15";
          boot = {
            plymouth.enable = true;
            kernelParams = [
              "radeon.dpm=1"
              "amd_pstate=active"
              "nouveau.config=NvGspRm=1"
              "nouveau.config=NvBoost=2"
              "nouveau.modeset=1"
            ];
            initrd.kernelModules = [ "amdgpu" ]; # Early KMS First stage of boot
            kernelModules = [ "zenpower" ]; # Second stage of boot process
            blacklistedKernelModules = [ "k10temp" ];
            extraModprobeConfig = ''
              options snd_hda_intel power_save=1
            '';
          };
          i18n.inputMethod = {
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
          # Desktop needs
          services.xserver = {
            enable = true;
            desktopManager.xfce = {
              enable = false;
              enableWaylandSession = true;
            };
          };
          services.libinput.enable = true;
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
          xdg.portal = {
            enable = true;
            xdgOpenUsePortal = true;
            extraPortals = [
              pkgs.xdg-desktop-portal-cosmic
              # pkgs.xdg-desktop-portal-gtk # niri
              # pkgs.xdg-desktop-portal-gnome # niri
            ];
          };
          # Polkit
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

          # secret service
          services.gnome.gnome-keyring.enable = true;
          services.passSecretService.enable = true;
          security.pam.services.login.enableGnomeKeyring = true;

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
          environment.systemPackages = with pkgs; [
            # file manager
            # xfce.thunar
            # xfce.thunar-archive-plugin
            # xarchiver
            # file-roller
            p7zip
            unzip
            zip
            unrar
            # file manager

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

            ## tools
            nvtopPackages.full
            virtualglLib
            vulkan-tools
            libva-utils
            vdpauinfo
            read-edid
            clinfo
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
          # bluetooth
          hardware.bluetooth = {
            enable = true;
            powerOnBoot = true;
            settings = {
              General = {
                # Shows battery charge of connected devices on supported
                # Bluetooth adapters. Defaults to 'false'.
                Experimental = true;
                # When enabled other devices can connect faster to us, however
                # the tradeoff is increased power consumption. Defaults to
                # 'false'.
                FastConnectable = true;
              };
              Policy = {
                # Enable all controllers when they are found. This includes
                # adapters present on start as well as adapters that are plugged
                # in later on. Defaults to 'true'.
                AutoEnable = true;
              };
            };
          };
          # GPU
          hardware.amdgpu.overdrive.enable = true;
          hardware.graphics = {
            enable = true;
            enable32Bit = true;
            extraPackages = with pkgs; [
              ## Scheduling layer
              vulkan-loader # Vulkan
              libglvnd # OpenGL
              ocl-icd # OpenCL
              rocmPackages.clr.icd

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
              rocmPackages.clr.icd

              ## drivers
              # driversi686Linux.amdvlk

              ## LIBs & Layer driver
              libva
              libvdpau
              driversi686Linux.libva-vdpau-driver
              driversi686Linux.libvdpau-va-gl
            ];
          };
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
                options nvidia NVreg_PreserveVideoMemoryAllocations=1
              '';
              hardware.nvidia = {
                open = true;
                modesetting.enable = true;
                nvidiaPersistenced = false;
                videoAcceleration = true;
                dynamicBoost.enable = true;
                powerManagement = {
                  enable = true;
                  finegrained = false; # conflict with sync
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
          services.xserver.videoDrivers = [ "nouveau" "amdgpu" ];
          # User defination
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
          programs.throne.enable = true;
          programs.clash-verge = {
            enable = true;
            serviceMode = true;
            package = pkgs.clash-verge-rev;
          };
          services.flatpak.enable = true;
          services.lact.enable = true;
          services.sunshine = {
            enable = true;
            autoStart = true;
            capSysAdmin = true;
            openFirewall = true;
          };
          systemd.services.fancontrol = {
            description = "Custom Fan Control Service";
            wants = [ "multi-user.target" ];
            after = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.writeShellScript "watch-store" ''
                #!/run/current-system/sw/bin/bash

                # 硬件接口路径
                PWM_ENABLE="/sys/devices/platform/hp-wmi/hwmon/$(ls /sys/devices/platform/hp-wmi/hwmon/)/pwm1_enable"
                PWM_CTRL="/sys/devices/platform/hp-wmi/hwmon/$(ls /sys/devices/platform/hp-wmi/hwmon/)/power/control"
                CPU_TEMP="/sys/devices/virtual/thermal/thermal_zone0/temp"
                GPU_TEMP="/sys/devices/virtual/thermal/thermal_zone1/temp"

                # 先启用手动控制模式
                echo on > "$PWM_CTRL"
                echo 2 > "$PWM_ENABLE"

                while true; do
                  # 读取 CPU（m°C）并转换为 ℃
                  cpu_c=$(( $(cat "$CPU_TEMP") / 1000 ))
                  # 读取 GPU 温度（整数 ℃）
                  gpu_c=$(( $(cat "$GPU_TEMP") / 1000 ))

                  # 取最大值
                  temp=$(( cpu_c > gpu_c ? cpu_c : gpu_c ))

                  if [ "$temp" -gt 70 ]; then
                    # 超过阈值 → 全速
                    echo 0 > "$PWM_ENABLE"
                  else
                    # 否则维持自动低速
                    echo 2 > "$PWM_ENABLE"
                  fi

                  sleep 5
                done
              ''}";
              Restart = "always";
              RestartSec = "5";
              Type = "simple";
            };
            wantedBy = [ "multi-user.target" ];
          };
        };
        "hostB" = {
          networking.hostName = "hostB";
          # hostB-specific adjustments
          services.httpd.enable = true;
          services.httpd.adminAddr = "admin@example.com";
        };
      };
      # merge the dnscrypt-proxy blocklist
      blocklist_base = builtins.readFile inputs.adlist;
      blocklist_txt = pkgs.writeText "blocklist.txt" blocklist_base;

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
