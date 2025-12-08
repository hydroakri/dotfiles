{ config, lib, pkgs, inputs, ... }: {
  networking.hostName = "omen15";
  nixpkgs.system = "x86_64-linux";
  imports = [
    # Hardware configuration
    # Auto-generated hardware config (can be regenerated with nixos-generate-config)
    ./hardware-configuration.nix

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
    sddm.enable = true;
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
  services.xserver.videoDrivers = lib.mkForce [ "nouveau" "amdgpu" ];
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
    # xwayland-satellite
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
      kdePackages.kate
      venera
      wezterm
      code-cursor
      # davinci-resolve-studio
    ];
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
  # ============================================================================
  # Custom Hardware Configuration
  # ============================================================================
  # Add additional kernel modules for better hardware support
  # sudo nixos-generate-config --show-hardware-config > ./hardware-configuration.nix (MUST be used in tty)
  boot.initrd.availableKernelModules = lib.mkAfter [ "usb_storage" "sd_mod" ];

  # Override filesystem mount options with performance optimizations
  fileSystems."/" = {
    options = lib.mkForce [
      "subvol=@"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=60"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  fileSystems."/nix" = {
    options = lib.mkForce [
      "subvol=@nix"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=60"
      "compress=zstd:3"
      "discard=async"
      "autodefrag"
    ];
  };

  fileSystems."/home" = {
    options = lib.mkForce [
      "subvol=@home"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=60"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  fileSystems."/var/log" = {
    options = lib.mkForce [
      "subvol=@log"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=60"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  # Override steam-linux filesystem to use label instead of UUID
  fileSystems."/steam-linux" = {
    device = lib.mkForce "LABEL=steam-linux";
    options = lib.mkForce [
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=60"
      "compress=zstd:3"
      "discard=async"
      "autodefrag"
    ];
  };

  # Enable DHCP by default for network interfaces
  networking.useDHCP = lib.mkDefault true;

}
