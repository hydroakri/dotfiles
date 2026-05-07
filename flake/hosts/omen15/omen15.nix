# nh os switch -H omen15 ./
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  networking.hostName = "omen15";
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
  ];
  imports = [
    # Hardware configuration
    ./disko.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/desktop.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/powersave.nix
    ../../modules/features/networking/proxy.nix
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
    networking.sqm = {
      enable = true;
      wanInterface = "wlo1";
      lanInterface = "wlo1";
    };
    networking.sysfsTuning = {
      enable = true;
      interfaces = {
        eno1 = {
          rps_cpus = "fe";
          xps_cpus = "fe";
        };
        wlo1 = {
          rps_cpus = "fe";
          xps_cpus = "fe";
        };
      };
    };
    proxy = {
      enable = true;
      singbox.enable = true;
      singbox.dns = true;
      singbox.tun = true;
      singbox.endpoints = true;
      singbox.outbounds = true;
    };
    utils = {
      enable = true;
      enableGraphicTools = true;
      enableGlance = true;
      enableUptime = true;
    };
  };
  boot = {
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-lts-lto-x86_64-v3;
    # kernelPackages = pkgs.linuxPackages_xanmod;
    kernelModules = [
      "zenpower"
      "kvm-amd"
    ];
    initrd.kernelModules = [ "amdgpu" ];
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "usbhid"
      "sdhci_pci"
      "usb_storage"
      "sd_mod"
    ];
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
  };
  i18n = {
    inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5 = {
        addons = [
          pkgs.fcitx5-rime
          pkgs.libsForQt5.fcitx5-qt
          pkgs.fcitx5-gtk
          pkgs.qt6Packages.fcitx5-configtool
          pkgs.qt6Packages.fcitx5-chinese-addons
          pkgs.fcitx5-lua
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
  users.users.${config.mainUser}.extraGroups = [
    "video"
    "i2c"
  ];
  environment.etc."nixos/nbfc.json".text = builtins.toJSON {
    SelectedConfigId = "HP OMEN Laptop 15-en0xxx";
  };
  environment.systemPackages = [
    # file manager
    # xfce.thunar
    # xfce.thunar-archive-plugin
    # xarchiver
    # file-roller
    # file manager
    pkgs.kdePackages.partitionmanager
    pkgs.kdePackages.kpmcore
    pkgs.opencode-desktop

    # Wayland compositor
    # xwayland-satellite
    # networkmanagerapplet
    pkgs.brightnessctl
    pkgs.pavucontrol
    pkgs.playerctl
    # blueman
    # qt6ct
    # mako
    # snixembed
    # waybar
    # xfce.xfconf
    # xfce.xfce4-panel
    # xfce.xfce4-panel-profiles
    # rofi

    pkgs.winboat

  ];
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

  system.stateVersion = "25.11";
}
