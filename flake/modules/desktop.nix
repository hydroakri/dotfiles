{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.nixpak.nixosModules.default ];

  config = {
    boot = {
      kernel.sysctl = {
        "kernel.printk" = "3 3 3 3";
      };
      consoleLogLevel = lib.mkDefault 3;
      initrd.verbose = false;
      plymouth.enable = true;
      kernelParams = [
        # boot screen
        "quiet"
        "splash"
        "loglevel=3"
        "rd.udev.log_level=3"
        "vt.global_cursor_default=0"
        "rd.systemd.show_status=auto"
        # PREEMPT
        "preempt=full"
        # blank bare VT backlight after 5min idle; wakes on keypress
        "consoleblank=300"
      ];
    };

    services.displayManager = {
      ly.enable = true;
      ly.settings.session_log = "null";
    };
    services.desktopManager = lib.mkDefault {
      cosmic = {
        enable = false;
        xwayland.enable = true;
      };
      # gnome.enable = true;
      # plasma6.enable = true;
    };

    # vm.swappiness default lives in performance.nix (mkDefault 180) — not
    # redefined here to avoid a duplicate bare-literal definition of the
    # same sysctl key across two modules.
    networking.networkmanager = {
      wifi.backend = lib.mkOverride 900 "iwd";
      settings."connection"."ipv6.ip6-privacy" = lib.mkOverride 900 2;
    };

    # X Server and input
    services.gpm.enable = true; # mouse support on bare virtual consoles
    services.xserver.enable = lib.mkOverride 900 true;
    services.libinput.enable = lib.mkOverride 900 true;
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    i18n = {
      inputMethod = {
        type = "fcitx5";
        enable = lib.mkOverride 900 true;
        fcitx5 = {
          addons = [
            pkgs.fcitx5-gtk
            (pkgs.fcitx5-rime.override {
              rimeDataPkgs = [ pkgs.rime-ice ];
            })
            pkgs.libsForQt5.fcitx5-qt
            pkgs.qt6Packages.fcitx5-qt
          ];
          waylandFrontend = true;
        };
      };
    };

    # Desktop portal
    xdg.portal = {
      enable = lib.mkOverride 900 true;
      xdgOpenUsePortal = lib.mkOverride 900 true;
      extraPortals = [
        # pkgs.xdg-desktop-portal-cosmic
        pkgs.xdg-desktop-portal-gtk # niri
        pkgs.xdg-desktop-portal-gnome # niri
      ];
    };

    # Polkit (privilege elevation)
    security.polkit.enable = lib.mkOverride 900 true;
    security.pam.services.polkit.enable = lib.mkOverride 900 true;
    systemd.user.services.polkit-agent = lib.mkIf (!config.services.desktopManager.plasma6.enable) {
      description = "polkit-agent";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        # ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    # Secret service (keyring) use keepassxc
    services.gnome.gnome-keyring.enable = lib.mkOverride 900 true;
    security.pam.services.login.enableGnomeKeyring = lib.mkOverride 900 true;
    services.passSecretService.enable = lib.mkOverride 900 true;
    services.gnome.gcr-ssh-agent.enable = lib.mkOverride 900 false; # disable ssh function managed by gnome-keyring
    services.dbus.packages = [ pkgs.gcr ];

    # For earlyoom and smartd notices
    services.systembus-notify.enable = lib.mkOverride 900 true;
    services.smartd.notifications.systembus-notify.enable = lib.mkOverride 900 true;

    # Printing
    services.printing.enable = lib.mkOverride 900 false;
    services.avahi.enable = lib.mkOverride 900 false;
    networking.modemmanager.enable = lib.mkOverride 900 false;
    services.geoclue2.enable = lib.mkOverride 900 true;

    # Audio (PipeWire)
    security.rtkit.enable = lib.mkOverride 900 true;
    services.pipewire = {
      enable = lib.mkOverride 900 true;
      alsa.enable = lib.mkOverride 900 true;
      alsa.support32Bit = lib.mkOverride 900 true;
      pulse.enable = lib.mkOverride 900 true;
      # ALSA 节点自动挂起,恢复时容易爆音/杂音
      wireplumber.extraConfig."51-disable-suspension" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.*"; }
              { "node.name" = "~alsa_output.*"; }
            ];
            actions.update-props."session.suspend-timeout-seconds" = 0;
          }
        ];
      };
    };
    #I2C
    hardware.i2c.enable = lib.mkOverride 900 true;
    # Bluetooth：保留驱动，收紧守护进程行为——可配对/可发现状态限时，开机不自动开
    # （powerOnBoot 也改 false，否则会跟 AutoEnable=false 冲突：systemd 层上电但
    # bluez policy 不自动启用，行为不一致）
    hardware.bluetooth = {
      enable = lib.mkOverride 900 true;
      powerOnBoot = lib.mkOverride 900 false;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
          PairableTimeout = 30;
          DiscoverableTimeout = 30;
          MaxControllers = 1;
        };
        Policy = {
          AutoEnable = false;
          # network/on：只接受用随机地址（RPA）广播的对端设备，牺牲部分老设备
          # 兼容性换隐私
          Privacy = "network/on";
        };
      };
    };

    # Battery
    services.upower.enable = lib.mkOverride 900 true;

    # Appimage
    programs.appimage = {
      enable = lib.mkOverride 900 true;
      binfmt = lib.mkOverride 900 true;
    };

    programs.niri.enable = lib.mkOverride 900 true;
    programs.kdeconnect.enable = lib.mkOverride 900 true;

    # Graphics support (base configuration)
    hardware.graphics = {
      enable = lib.mkOverride 900 true;
      enable32Bit = lib.mkOverride 900 true;
      extraPackages = [
        ## Scheduling layer
        pkgs.vulkan-loader # Vulkan
        pkgs.libglvnd # OpenGL
        pkgs.ocl-icd # OpenCL

        ## drivers
        # amdvlk

        ## LIBs & Layer driver
        pkgs.libva
        pkgs.libvdpau
        pkgs.libvdpau-va-gl
        pkgs.libva-vdpau-driver
      ];
      extraPackages32 = [
        ## Scheduling layer
        pkgs.vulkan-loader # Vulkan
        pkgs.libglvnd # OpenGL
        pkgs.ocl-icd # OpenCL

        ## drivers
        # driversi686Linux.amdvlk

        ## LIBs & Layer driver
        pkgs.libva
        pkgs.libvdpau
        pkgs.driversi686Linux.libva-vdpau-driver
        pkgs.driversi686Linux.libvdpau-va-gl
      ];
    };
    # Flatpak
    services.flatpak.enable = lib.mkOverride 900 true;

    # Daily flatpak cleanup: remove unused runtimes and repair
    # Runs as main user; catches up on missed runs after boot (Persistent=true)
    systemd.timers.flatpak-cleanup = lib.mkIf config.services.flatpak.enable {
      description = "Daily Flatpak cleanup timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    systemd.services.flatpak-cleanup = lib.mkIf config.services.flatpak.enable {
      description = "Flatpak cleanup service";
      path = [ pkgs.flatpak ];
      script = ''
        flatpak uninstall --unused --noninteractive
        flatpak repair --noninteractive
      '';
      serviceConfig = {
        Type = "oneshot";
        User = config.mainUser;
      };
    };

    environment.plasma6.excludePackages = [
      pkgs.kdePackages.elisa
      pkgs.kdePackages.gwenview
      pkgs.kdePackages.kwrited
      pkgs.kdePackages.khelpcenter
      pkgs.kdePackages.konqueror
      pkgs.kdePackages.oxygen
      pkgs.kdePackages.krdc
      pkgs.kdePackages.krfb
      pkgs.kdePackages.dragon
      pkgs.kdePackages.kcalc
      pkgs.kdePackages.kfind
      pkgs.kdePackages.kcharselect
      pkgs.kdePackages.keditbookmarks
      pkgs.kdePackages.drkonqi
      pkgs.kdePackages.kdebugsettings
      pkgs.kdePackages.kjournald
      pkgs.kdePackages.ksystemlog
      pkgs.kdePackages.kamera
      pkgs.kdePackages.audiocd-kio
      pkgs.kdePackages.ffmpegthumbs
      pkgs.kdePackages.kwallet
      pkgs.kdePackages.kwallet-pam
      pkgs.kdePackages.kwalletmanager
      pkgs.kdePackages.qrca
      pkgs.kdePackages.discover
    ];
    environment.cosmic.excludePackages = [
      pkgs.cosmic-player
      pkgs.cosmic-term
      pkgs.cosmic-edit
    ];
    environment.gnome.excludePackages = [
      pkgs.atomix # puzzle game
      pkgs.cheese # webcam tool
      pkgs.epiphany # web browser
      pkgs.evince # document viewer
      pkgs.geary # email reader
      pkgs.gedit # text editor
      pkgs.gnome-characters
      pkgs.gnome-music
      pkgs.gnome-photos
      pkgs.gnome-terminal
      pkgs.gnome-tour
      pkgs.hitori # sudoku game
      pkgs.iagno # go game
      pkgs.tali # poker game
      pkgs.totem # video player
    ];
    fonts = {
      packages = [
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-cjk-serif
        pkgs.noto-fonts-color-emoji
        pkgs.nerd-fonts.symbols-only
        pkgs.iosevka # monospace
        pkgs.commit-mono # monospace
        pkgs.source-serif # serif
        pkgs.libertinus # math/latex
        pkgs.inter # sans
      ];
      fontDir = {
        enable = true;
        decompressFonts = true;
      };
      fontconfig.defaultFonts = {
        sansSerif = [ ];
        serif = [ ];
        monospace = [ ];
        emoji = [ "Noto Color Emoji" ];
      };
    };

    programs.thunar = {
      enable = lib.mkOverride 900 true;
      plugins = [
        pkgs.thunar-archive-plugin
        pkgs.thunar-volman
        # file manager
        pkgs.xarchiver
        pkgs.file-roller
      ];
    };
    services.gvfs.enable = lib.mkOverride 900 true;
    services.tumbler.enable = lib.mkOverride 900 true;

    # 深浅主题完全由 darkman 通过 gsettings 管理，这里不写死任何值。
    # 只保证 dconf 服务存在，gsettings 写入才可用。
    programs.dconf.enable = true;

    # gsettings 二进制 + schemas；并把 schema 目录加入会话 XDG_DATA_DIRS，
    # 否则 darkman 脚本里的 gsettings 报 "No schemas installed"。
    environment.systemPackages = [
      #theme
      pkgs.darkly
      pkgs.bibata-cursors
      pkgs.papirus-icon-theme
      pkgs.darkman
      pkgs.adw-gtk3
      pkgs.adwaita-qt
      pkgs.adwaita-qt6
      pkgs.qt6Packages.qt6ct
      pkgs.libsForQt5.qt5ct
      pkgs.glib
      pkgs.gsettings-desktop-schemas
      pkgs.python3 # noctalia's template processor + gtk-refresh script need it in PATH

      # GUI Applications
      pkgs.wezterm
      pkgs.junction

      # clipboard
      pkgs.wl-clipboard
      pkgs.wl-clip-persist
      pkgs.wl-clipboard-x11
      pkgs.cliphist

      # Wayland compositor
      pkgs.xwayland-satellite # niri
      pkgs.noctalia
      # pkgs.networkmanagerapplet
      pkgs.brightnessctl
      pkgs.pavucontrol
      pkgs.playerctl
    ]
    ++ lib.optionals config.services.desktopManager.plasma6.enable [
      pkgs.kdePackages.partitionmanager
      pkgs.kdePackages.kpmcore
      pkgs.kdePackages.krohnkite
      pkgs.kdePackages.kate
    ]
    ++ lib.optionals config.services.desktopManager.gnome.enable [
      pkgs.gnome-tweaks
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.user-themes
      pkgs.gnomeExtensions.kimpanel
    ];

    # 让会话内的 gsettings 能找到 desktop schemas（NixOS 不会自动加这个目录）
    environment.sessionVariables.XDG_DATA_DIRS = [
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
    ];

    security.nixpak = {
      enable = true;
      defaults = { sloth, ... }: {
        bubblewrap = {
          network = true;
          dieWithParent = true;
          sockets = {
            wayland = true;
            pipewire = true;
          };
          tmpfs = [
            "/tmp"
            "/dev/shm"
          ];
          bind.ro = [
            "/etc/passwd"
            "/etc/group"
            "/etc/nsswitch.conf"
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            (sloth.concat' sloth.xdgDataHome "/mime")
          ];
          bind.rw = [
            (sloth.concat' sloth.runtimeDir "/fcitx5")
            (sloth.concat' sloth.runtimeDir "/fcitx")
            (sloth.concat' sloth.runtimeDir "/doc")
            (sloth.concat' sloth.runtimeDir "/pulse")
          ];
        };
        gpu.enable = true;
        etc.sslCertificates.enable = true;
        locale.enable = true;
      };

      apps = {
        brave.configuration = { pkgs, sloth, ... }: {
          app.package = pkgs.brave;
          flatpak.appId = "com.brave.Browser";
          dbus.policies = {
            "org.freedesktop.DBus" = "talk";
            "ca.desrt.dconf" = "talk";
            "org.freedesktop.portal.*" = "talk";
          };
          pasta = {
            enable = true;
            mode = "transparent";
          };
          timeZone = {
            enable = true;
            provider = "bundle";
          };
          bubblewrap.env = {
            NIXOS_OZONE_WL = "1";
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
            FONTCONFIG_FILE = "${pkgs.mullvad-browser}/share/mullvad-browser/fonts/fonts.conf";
          };
          bubblewrap.bind.ro = [
            "/etc/brave"
            "/etc/dconf"
            (sloth.concat' sloth.xdgConfigHome "/dconf")
            (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
          ];
          bubblewrap.bind.rw = [
            (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/BraveSoftware"))
            (sloth.mkdir (sloth.concat' sloth.xdgDataHome "/BraveSoftware"))
            (sloth.mkdir (sloth.concat' sloth.xdgCacheHome "/BraveSoftware"))
            (sloth.mkdir sloth.xdgDownloadDir)
          ];
        };

        mullvad-browser.configuration = { pkgs, sloth, ... }: {
          app.package = pkgs.mullvad-browser;
          flatpak.appId = "net.mullvad.MullvadBrowser";
          dbus.policies = {
            "org.freedesktop.DBus" = "talk";
            "org.freedesktop.portal.*" = "talk";
          };
          timeZone = {
            enable = true;
            provider = "bundle";
          };
          pasta = {
            enable = true;
            mode = "transparent";
          };
          bubblewrap.env = {
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
          };
          bubblewrap.tmpfs = [ (sloth.concat' sloth.homeDir "/.mullvad-browser") ];
          bubblewrap.bind.rw = [ (sloth.mkdir sloth.xdgDownloadDir) ];
        };
      };
    };

    # GUI User profile
    services.cloudflare-warp.enable = lib.mkOverride 900 true;
    # sops-nix places secrets as symlinks; warp-svc opens its MDM policy file
    # with O_NOFOLLOW, so a symlinked mdm.xml fails with ELOOP and the client
    # never registers. Copy the secret into a real file before each start.
    sops.secrets."warp_mdm" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "cloudflare-warp.service" ];
    };
    systemd.services.cloudflare-warp.preStart = ''
      install -m 0400 -o root -g root /run/secrets/warp_mdm /var/lib/cloudflare-warp/mdm.xml.tmp
      mv -f /var/lib/cloudflare-warp/mdm.xml.tmp /var/lib/cloudflare-warp/mdm.xml
    '';
    users.users.${config.mainUser} = {
      extraGroups = [
        "video"
        "i2c"
      ];
    };
  };
}
