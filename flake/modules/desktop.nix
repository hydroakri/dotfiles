{
  config,
  pkgs,
  lib,
  ...
}:
{
  boot.kernelParams = [ "preempt=full" ];
  boot.kernel.sysctl = {
    # Desktop-specific VM tuning
    "vm.swappiness" = 180;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
  networking.networkmanager.settings = {
    "connection" = {
      "ipv6.ip6-privacy" = 2;
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
      # pkgs.xdg-desktop-portal-cosmic
      # pkgs.xdg-desktop-portal-gtk # niri
      # pkgs.xdg-desktop-portal-gnome # niri
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
  services.printing.enable = true;

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

  # Appimage
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

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

  # Desktop firewall (general application ports)
  networking.firewall = {
    allowedTCPPorts = [ 1080 ];
    allowedUDPPorts = [ 1080 ];
  };
  environment.plasma6.excludePackages = (
    [
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
    ]
  );
  environment.cosmic.excludePackages = (
    [
      pkgs.cosmic-player
      pkgs.cosmic-term
      pkgs.cosmic-edit
    ]
  );
  environment.gnome.excludePackages = (
    [
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
    ]
  );
  fonts = {
    packages = [
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-cjk-serif
      pkgs.noto-fonts-color-emoji
      pkgs.sarasa-gothic
      pkgs.nerd-fonts.symbols-only
      pkgs.cascadia-code # monospace
      pkgs.source-serif # serif
      pkgs.libertinus # math/latex
      pkgs.inter # sans
    ];
    fontDir = {
      enable = true;
      decompressFonts = true;
    };
  };
  environment.systemPackages = [
    #theme
    pkgs.darkly-qt5
    pkgs.darkly
    pkgs.darkman
  ];

  # Darkman for automatic theme switching
  systemd.user.services.darkman = {
    description = "Darkman daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.darkman}/bin/darkman run";
      Restart = "always";
    };
    environment = {
      XDG_CONFIG_HOME = "%h/.config";
    };
  };

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
      pkgs.gnomeExtensions.appindicator
      pkgs.gnomeExtensions.user-themes
      pkgs.gnomeExtensions.kimpanel
      pkgs.gnome-tweaks

      # GUI Applications
      pkgs.venera
      pkgs.wezterm
      pkgs.kdePackages.kate
      # davinci-resolve-studio
    ];
  };
}
