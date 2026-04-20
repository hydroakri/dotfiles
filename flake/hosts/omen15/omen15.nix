# nh os switch -H omen15 ./
{ config, lib, pkgs, inputs, ... }: {
  networking.hostName = "omen15";
  nixpkgs.hostPlatform = "x86_64-linux";
  imports = [
    # Hardware configuration
    ./disko.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/desktop.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/powersave.nix
    ../../modules/features/proxy.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix
    ../../modules/features/utils.nix
    ../../modules/features/virtualisation.nix
    ../../modules/features/gaming.nix

    # Filesystem modules
    ../../modules/filesystems/btrfs.nix

    # Hardware-specific modules
    ../../modules/hardware/amd.nix
    ../../modules/hardware/nvidia.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
  ];
  modules = {
    nvidia.enable = true;
    proxy = {
      enable = true;
      enableDnsCryptProxy = false;
      enableDae = false;
      enableSingbox = true;
    };
    utils = {
      enable = true;
      enableGraphicTools = true;
      enableGlance = true;
      enableUptime = true;
      enableGrafana = false;
      enablePrometheus = false;
    };
  };
  boot = {
    kernelPackages = pkgs.linuxPackages_xanmod;
    kernelModules = [ "zenpower" "kvm-amd" ];
    initrd.kernelModules = [ "amdgpu" ];
    initrd.availableKernelModules =
      [ "nvme" "xhci_pci" "usbhid" "sdhci_pci" "usb_storage" "sd_mod" ];
    blacklistedKernelModules = [ "k10temp" ];
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    extraModprobeConfig = ''
      options snd_hda_intel power_save=1
      options zenpower fast_ctemp=1
    '';
    loader.efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    loader.limine = {
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
    kernel.sysfs = {
      # enable net card RPS & XPS
      class.net.eno1.queues."rx-0".rps_cpus = "fe";
      class.net.eno1.queues."tx-0".xps_cpus = "fe";

      class.net.wlo1.queues."rx-0".rps_cpus = "fe";
      class.net.wlo1.queues."tx-0".xps_cpus = "fe";
    };
  };
  i18n = {
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
  services.displayManager = {
    plasma-login-manager.enable = true;

    # gdm.enable = true;
    # cosmic-greeter.enable = true;
  };
  services.desktopManager = {
    cosmic = {
      enable = false;
      xwayland.enable = true;
    };
    # gnome.enable = true;
    plasma6.enable = true;
  };
  # Video drivers (hardware-specific)
  # services.xserver.videoDrivers = [ "amdgpu" "nouveau" ];
  services.xserver.desktopManager.xfce = {
    enable = false;
    enableWaylandSession = true;
  };
  networking.networkmanager.insertNameservers = [ "127.0.0.1" ];
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
    opencode-desktop

    # Wayland compositor
    # xwayland-satellite
    # networkmanagerapplet
    brightnessctl
    pavucontrol
    playerctl
    # blueman
    # qt6ct
    # mako
    # snixembed
    # waybar
    # xfce.xfconf
    # xfce.xfce4-panel
    # xfce.xfce4-panel-profiles
    # rofi

  ];
  # User definition
  users.users.${config.mainUser} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${config.mainUser}";
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      # themes/shell/plugin
      bibata-cursors
      papirus-icon-theme
      gnomeExtensions.appindicator
      gnomeExtensions.user-themes
      gnomeExtensions.kimpanel
      gnome-tweaks

      # GUI Applications
      venera
      wezterm
      code-cursor
      kdePackages.kate
      # davinci-resolve-studio
    ];
  };
  # programs.niri.enable = true;
  programs.kdeconnect.enable = true;
  # Application-specific programs (host-specific)
  programs.throne.enable = false;
  programs.clash-verge = {
    enable = false;
    serviceMode = true;
    package = pkgs.clash-verge-rev;
  };
  # systemd.services.dae.wantedBy = lib.mkForce [ ]; # prevent dae auto start
  # systemd.services.dnscrypt-proxy.wantedBy = lib.mkForce [ ];
  services.cloudflare-warp.enable = true;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  # ============================================================================
  # Custom Hardware Configuration
  # ============================================================================
  # Enable DHCP by default for network interfaces
  networking.useDHCP = lib.mkDefault true;

}
