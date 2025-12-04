{ config, pkgs, ... }: {
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
  systemd.user.services.polkit-agent = {
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
  environment.plasma6.excludePackages =
    (with pkgs; [ kdePackages.elisa kdePackages.gwenview kdePackages.kwrited ]);
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

}
