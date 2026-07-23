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
      ];
    };

    services.displayManager = lib.mkDefault {
      ly.enable = true;
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
            pkgs.fcitx5-rime
            pkgs.rime-wanxiang
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
    services.geoclue2.enable = lib.mkOverride 1500 false;

    # Audio (PipeWire)
    security.rtkit.enable = lib.mkOverride 900 true;
    services.pipewire = {
      enable = lib.mkOverride 900 true;
      alsa.enable = lib.mkOverride 900 true;
      alsa.support32Bit = lib.mkOverride 900 true;
      pulse.enable = lib.mkOverride 900 true;
    };
    #I2C
    hardware.i2c.enable = lib.mkOverride 900 true;
    # Bluetooth
    hardware.bluetooth = {
      enable = lib.mkOverride 900 true;
      powerOnBoot = lib.mkOverride 900 true;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
        };
        Policy = {
          AutoEnable = true;
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

    environment.systemPackages = [
      #theme
      pkgs.darkly

      # clipboard
      pkgs.wl-clipboard
      pkgs.wl-clip-persist
      pkgs.wl-clipboard-x11
      pkgs.cliphist

      # Wayland compositor
      pkgs.xwayland-satellite # niri
      pkgs.noctalia-shell
      pkgs.noctalia-qs
      # pkgs.networkmanagerapplet
      pkgs.brightnessctl
      pkgs.pavucontrol
      pkgs.playerctl
      pkgs.qt6Packages.qt6ct
      # blueman
      # mako
      # snixembed
      # waybar
      # xfce.xfconf
      # xfce.xfce4-panel
      # xfce.xfce4-panel-profiles
      # rofi
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
            mode = "isolate";
          };
          fonts.enable = true;
          timeZone = {
            enable = true;
            provider = "bundle";
          };
          bubblewrap.env = {
            NIXOS_OZONE_WL = "1";
            LANG = "en_US.UTF-8";
            LC_ALL = "en_US.UTF-8";
          };
          bubblewrap.bind.ro = [
            "/etc/brave"
            "/etc/dconf"
            "/etc/fonts"
            (sloth.concat' sloth.xdgConfigHome "/fontconfig")
            (sloth.concat' sloth.xdgConfigHome "/dconf")
            (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
            (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
            (sloth.concat' sloth.xdgDataHome "/fonts")
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
          fonts.enable = true;
          timeZone = {
            enable = true;
            provider = "bundle";
          };
          pasta = {
            enable = true;
            mode = "isolate";
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
    users.users.${config.mainUser} = {
      extraGroups = [
        "video"
        "i2c"
      ];
      packages = [
        # themes/shell/plugin
        pkgs.bibata-cursors
        pkgs.papirus-icon-theme

        # GUI Applications
        pkgs.wezterm
        # davinci-resolve-studio
        pkgs.claude-code
        pkgs.opencode
        pkgs.junction
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
    };
  };
}
