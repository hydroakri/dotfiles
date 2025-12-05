{ config, lib, pkgs, inputs, ... }: {
  networking.hostName = "omen15";
  nixpkgs.system = "x86_64-linux";
  imports = [
    # Hardware configuration
    # Auto-generated hardware config (can be regenerated with nixos-generate-config)
    ./hardware-configuration.nix
    # Custom hardware configuration (manual modifications and optimizations)
    ./hardware-custom.nix

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
    inputs.home-manager.nixosModules.home-manager

    # Home manager configuration
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
      home-manager.users.hydroakri = import ../../users/hydroakri.nix;
    }
  ];
  boot = {
    kernelPackages = pkgs.linuxPackages_xanmod;
    kernelModules = [ "zenpower" ];
    blacklistedKernelModules = [ "k10temp" ];
    initrd.kernelModules = [ "amdgpu" ];
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    extraModprobeConfig = ''
      options snd_hda_intel power_save=1
    '';
    loader.efi.canTouchEfiVariables = true;
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
  time.timeZone = "Australia/Perth";
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
  services.xserver.desktopManager.xfce = {
    enable = false;
    enableWaylandSession = true;
  };
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

  ];
  # Video drivers (hardware-specific)
  services.xserver.videoDrivers = [ "nouveau" "amdgpu" ];
  # User definition
  users.users.hydroakri = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "hydroakri";
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };
  # programs.niri.enable = true;
  programs.zsh.enable = true;
  # Application-specific programs (host-specific)
  programs.throne.enable = true;
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    package = pkgs.clash-verge-rev;
  };
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

}
