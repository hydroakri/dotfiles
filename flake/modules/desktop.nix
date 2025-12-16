{ config, pkgs, lib, ... }: {
  boot.kernelParams = [ "preempt=full" ];
  boot.kernel.sysctl = {
    # Desktop-specific VM tuning
    "vm.swappiness" = lib.mkForce 180;
    "vm.dirty_ratio" = lib.mkForce 10;
    "vm.dirty_background_ratio" = lib.mkForce 5;
    # ipv6 privacy
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 2;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 2;
  };
  networking.networkmanager.settings = {
    "connection" = { "ipv6.ip6-privacy" = 2; };
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
  systemd.user.services.polkit-agent =
    lib.mkIf (!config.services.desktopManager.plasma6.enable) {
      description = "polkit-agent";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        # ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        ExecStart =
          "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

  # Secret service (keyring) use keepassxc
  services.gnome.gnome-keyring.enable = false;
  security.pam.services.login.enableGnomeKeyring = false;
  services.passSecretService.enable = false;

  # For earlyoom and smartd notices
  services.systembus-notify.enable = lib.mkForce true;
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

  # Desktop firewall (general application ports)
  networking.firewall = {
    allowedTCPPorts = [ 1080 ];
    allowedUDPPorts = [ 1080 ];
  };
  environment.plasma6.excludePackages = (with pkgs; [
    kdePackages.elisa
    kdePackages.gwenview
    kdePackages.kwrited
    kdePackages.khelpcenter
    kdePackages.konqueror
    kdePackages.oxygen
    kdePackages.krdc
    kdePackages.krfb
    kdePackages.dragon
    kdePackages.kcalc
    kdePackages.kfind
    kdePackages.kcharselect
    kdePackages.keditbookmarks
    kdePackages.drkonqi
    kdePackages.kdebugsettings
    kdePackages.kjournald
    kdePackages.ksystemlog
    kdePackages.kamera
    kdePackages.audiocd-kio
    kdePackages.ffmpegthumbs
    kdePackages.kwallet
    kdePackages.kwallet-pam
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
  fonts = {
    packages = with pkgs; [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      sarasa-gothic
      nerd-fonts.symbols-only
      cascadia-code # monospace
      source-serif # serif
      libertinus # math/latex
      inter # sans
    ];
    fontDir = {
      enable = true;
      decompressFonts = true;
    };
  };
  environment.systemPackages = with pkgs; [
    #theme
    darkly-qt5
    darkly
  ];
}
