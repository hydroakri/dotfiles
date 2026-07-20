{
  config,
  pkgs,
  lib,
  ...
}:
{
  config =
    let
      brave-sandboxed =
        let
          wrapper = pkgs.writeShellScriptBin "brave" ''
            set -euo pipefail
            XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
            WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-0}"
            DOWNLOAD_DIR="''${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
            mkdir -p "$HOME/.config/BraveSoftware" "$HOME/.local/share/BraveSoftware" \
                     "$HOME/.cache/BraveSoftware" "$DOWNLOAD_DIR"

            BWRAP_EXTRA=()
            [ -S "$XDG_RUNTIME_DIR/pipewire-0" ] \
              && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0")
            [ -S "$XDG_RUNTIME_DIR/pulse/native" ] \
              && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse")
            # ponytail: D-Bus 直接绑定；严格隔离需 xdg-dbus-proxy，加入当 D-Bus 成为实际攻击路径时
            _DBUS="''${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
            [ -n "$_DBUS" ] && [ -S "$_DBUS" ] && BWRAP_EXTRA+=(--bind "$_DBUS" "$_DBUS")
            [ -e "$XDG_RUNTIME_DIR/fcitx5" ] \
              && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/fcitx5" "$XDG_RUNTIME_DIR/fcitx5")
            [ -d "$XDG_RUNTIME_DIR/fcitx" ] \
              && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/fcitx" "$XDG_RUNTIME_DIR/fcitx")
            [ -d "$XDG_RUNTIME_DIR/doc" ] \
              && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/doc" "$XDG_RUNTIME_DIR/doc")

            exec ${pkgs.bubblewrap}/bin/bwrap \
              --ro-bind /nix /nix \
              --proc /proc --dev /dev --dev-bind /dev/dri /dev/dri \
              --ro-bind /sys/dev/char /sys/dev/char \
              --ro-bind /sys/devices/pci0000:00 /sys/devices/pci0000:00 \
              --tmpfs /tmp --tmpfs /dev/shm \
              --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
              --ro-bind-try /etc/hosts /etc/hosts \
              --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf \
              --ro-bind-try /etc/passwd /etc/passwd \
              --ro-bind-try /etc/group /etc/group \
              --ro-bind-try /etc/ssl /etc/ssl \
              --ro-bind-try /etc/localtime /etc/localtime \
              --ro-bind-try /etc/locale.conf /etc/locale.conf \
              --ro-bind-try /etc/fonts /etc/fonts \
              --ro-bind-try /etc/brave /etc/brave \
              --ro-bind-try /etc/dconf /etc/dconf \
              --ro-bind-try "$HOME/.config/fontconfig" "$HOME/.config/fontconfig" \
              --ro-bind-try "$HOME/.config/dconf" "$HOME/.config/dconf" \
              --ro-bind-try "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-3.0" \
              --ro-bind-try "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-4.0" \
              --ro-bind /run /run \
              --tmpfs "$XDG_RUNTIME_DIR" \
              --bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" \
              --bind "$HOME/.config/BraveSoftware" "$HOME/.config/BraveSoftware" \
              --bind "$HOME/.local/share/BraveSoftware" "$HOME/.local/share/BraveSoftware" \
              --bind "$HOME/.cache/BraveSoftware" "$HOME/.cache/BraveSoftware" \
              --bind "$DOWNLOAD_DIR" "$DOWNLOAD_DIR" \
              --ro-bind-try "$HOME/.config/user-dirs.dirs" "$HOME/.config/user-dirs.dirs" \
              --ro-bind-try "$HOME/.local/share/fonts" "$HOME/.local/share/fonts" \
              --ro-bind-try "$HOME/.local/share/mime" "$HOME/.local/share/mime" \
              "''${BWRAP_EXTRA[@]}" \
              --unshare-uts --unshare-ipc --unshare-pid --die-with-parent \
              -- ${pkgs.brave}/bin/brave \
              --ozone-platform=wayland \
              --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,AudioServiceSandbox \
              "$@"
          '';
          desktopEntry =
            {
              name,
              desktopName,
              noDisplay ? false,
            }:
            pkgs.makeDesktopItem {
              inherit name desktopName;
              noDisplay = if noDisplay then true else null;
              genericName = "Web Browser";
              comment = "Access the Internet";
              icon = "brave-browser";
              exec = "${wrapper}/bin/brave %U";
              terminal = false;
              startupNotify = true;
              categories = [
                "Network"
                "WebBrowser"
              ];
              mimeTypes = [
                "application/pdf"
                "application/rdf+xml"
                "application/rss+xml"
                "application/xhtml+xml"
                "application/xhtml_xml"
                "application/xml"
                "image/gif"
                "image/jpeg"
                "image/png"
                "image/webp"
                "text/html"
                "text/xml"
                "x-scheme-handler/http"
                "x-scheme-handler/https"
                "x-scheme-handler/chromium"
              ];
              actions = {
                new-window = {
                  name = "New Window";
                  exec = "${wrapper}/bin/brave";
                };
                new-private-window = {
                  name = "New Incognito Window";
                  exec = "${wrapper}/bin/brave --incognito";
                };
              };
            };
        in
        pkgs.symlinkJoin {
          name = "brave";
          paths = [
            wrapper
            (desktopEntry {
              name = "brave-browser";
              desktopName = "Brave Web Browser";
            })
            (desktopEntry {
              name = "com.brave.Browser";
              desktopName = "Brave Web Browser";
              noDisplay = true;
            })
          ];
        };
      mullvad-sandboxed = pkgs.writeShellScriptBin "mullvad-browser" ''
        set -euo pipefail
        XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-0}"
        DOWNLOAD_DIR="''${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
        mkdir -p "$HOME/.mullvad-browser" "$DOWNLOAD_DIR"

        BWRAP_EXTRA=()
        [ -S "$XDG_RUNTIME_DIR/pipewire-0" ] \
          && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0")
        [ -S "$XDG_RUNTIME_DIR/pulse/native" ] \
          && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse")
        _DBUS="''${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
        [ -n "$_DBUS" ] && [ -S "$_DBUS" ] && BWRAP_EXTRA+=(--bind "$_DBUS" "$_DBUS")
        [ -e "$XDG_RUNTIME_DIR/fcitx5" ] \
          && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/fcitx5" "$XDG_RUNTIME_DIR/fcitx5")
        [ -d "$XDG_RUNTIME_DIR/fcitx" ] \
          && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/fcitx" "$XDG_RUNTIME_DIR/fcitx")
        [ -d "$XDG_RUNTIME_DIR/doc" ] \
          && BWRAP_EXTRA+=(--bind "$XDG_RUNTIME_DIR/doc" "$XDG_RUNTIME_DIR/doc")

        exec ${pkgs.bubblewrap}/bin/bwrap \
          --ro-bind /nix /nix \
          --proc /proc --dev /dev --dev-bind /dev/dri /dev/dri \
          --ro-bind /sys/dev/char /sys/dev/char \
          --ro-bind /sys/devices/pci0000:00 /sys/devices/pci0000:00 \
          --tmpfs /tmp --tmpfs /dev/shm \
          --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
          --ro-bind-try /etc/hosts /etc/hosts \
          --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf \
          --ro-bind-try /etc/passwd /etc/passwd \
          --ro-bind-try /etc/group /etc/group \
          --ro-bind-try /etc/ssl /etc/ssl \
          --ro-bind-try /etc/localtime /etc/localtime \
          --ro-bind-try /etc/locale.conf /etc/locale.conf \
          --ro-bind-try /etc/fonts /etc/fonts \
          --ro-bind /run /run \
          --tmpfs "$XDG_RUNTIME_DIR" \
          --bind "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" \
          --tmpfs "$HOME/.mullvad-browser" \
          --bind "$DOWNLOAD_DIR" "$DOWNLOAD_DIR" \
          --ro-bind-try "$HOME/.config/user-dirs.dirs" "$HOME/.config/user-dirs.dirs" \
          --ro-bind-try "$HOME/.local/share/fonts" "$HOME/.local/share/fonts" \
          --ro-bind-try "$HOME/.local/share/mime" "$HOME/.local/share/mime" \
          "''${BWRAP_EXTRA[@]}" \
          --unshare-uts --unshare-ipc --unshare-pid --die-with-parent \
          -- ${pkgs.mullvad-browser}/bin/mullvad-browser "$@"
      '';
    in
    {
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

          pkgs.brave
          (lib.hiPrio brave-sandboxed)
          pkgs.mullvad-browser
          (lib.hiPrio mullvad-sandboxed)
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
