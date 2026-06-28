{
  config,
  pkgs,
  lib,
  ...
}:
{
  config =
    let
      brave-sandboxed = pkgs.writeShellScriptBin "brave" ''
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
          --ro-bind /etc /etc \
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
          --unshare-uts --unshare-ipc --die-with-parent \
          -- ${pkgs.brave}/bin/brave \
          --ozone-platform=wayland \
          --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer,AudioServiceSandbox \
          "$@"
      '';
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
          --unshare-uts --unshare-ipc --die-with-parent \
          -- ${pkgs.mullvad-browser}/bin/mullvad-browser "$@"
      '';
    in
    {
      boot = {
        kernel.sysctl = {
          "kernel.printk" = "3 3 3 3";
        };
        consoleLogLevel = 3;
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

      boot.kernel.sysctl = {
        # Desktop-specific VM tuning
        "vm.swappiness" = 180;
      };
      networking.networkmanager = {
        wifi.backend = lib.mkDefault "iwd";
        settings."connection"."ipv6.ip6-privacy" = 2;
      };

      # X Server and input
      services.xserver.enable = true;
      services.libinput.enable = true;
      services.xserver.xkb = {
        layout = "us";
        variant = "";
      };

      i18n = {
        inputMethod = {
          type = "fcitx5";
          enable = true;
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
        enable = true;
        xdgOpenUsePortal = true;
        extraPortals = [
          # pkgs.xdg-desktop-portal-cosmic
          pkgs.xdg-desktop-portal-gtk # niri
          pkgs.xdg-desktop-portal-gnome # niri
        ];
      };

      # Polkit (privilege elevation)
      security.polkit.enable = true;
      security.pam.services.polkit.enable = true;
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
      services.gnome.gnome-keyring.enable = true;
      security.pam.services.login.enableGnomeKeyring = true;
      services.passSecretService.enable = true;
      services.gnome.gcr-ssh-agent.enable = false; # disable ssh function managed by gnome-keyring
      services.dbus.packages = [ pkgs.gcr ];

      # For earlyoom and smartd notices
      services.systembus-notify.enable = true;
      services.smartd.notifications.systembus-notify.enable = true;

      # Printing
      services.printing.enable = false;
      services.avahi.enable = false;
      networking.modemmanager.enable = false;
      services.geoclue2.enable = lib.mkDefault false;

      # Audio (PipeWire)
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      #I2C
      hardware.i2c.enable = true;
      # Bluetooth
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
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
      services.upower.enable = true;

      # Appimage
      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      programs.niri.enable = true;
      programs.kdeconnect.enable = true;

      # Graphics support (base configuration)
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
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
      services.flatpak.enable = true;

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

      # Desktop firewall (general application ports)
      networking.firewall = {
        allowedTCPPorts = [ 1080 ];
        allowedUDPPorts = [ 1080 ];
      };
      environment.plasma6.excludePackages = ([
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
      ]);
      environment.cosmic.excludePackages = ([
        pkgs.cosmic-player
        pkgs.cosmic-term
        pkgs.cosmic-edit
      ]);
      environment.gnome.excludePackages = ([
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
      ]);
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
      };

      programs.thunar = {
        enable = true;
        plugins = [
          pkgs.thunar-archive-plugin
          pkgs.thunar-volman
          # file manager
          pkgs.xarchiver
          pkgs.file-roller
        ];
      };
      services.gvfs.enable = true;
      services.tumbler.enable = true;

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
        pkgs.claude-code
        pkgs.opencode
        pkgs.junction
      ];

      # GUI User profile
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

          # Brave：pkgs.brave 提供 .desktop 文件和图标；
          # brave-sandboxed 以 lib.hiPrio 覆盖 brave 二进制，指向 bubblewrap 包装器。
          # 从应用菜单点击 Brave 图标时，.desktop 的 Exec=brave 会调用包装器。
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
