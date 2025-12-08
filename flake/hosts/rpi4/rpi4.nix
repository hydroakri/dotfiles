{ config, lib, pkgs, inputs, ... }: {
  networking.hostName = "rpi4";
  nixpkgs.system = "aarch64-linux";
  nix.registry.nixpkgs.to = {
    type = "tarball";
    url =
      "https://mirrors.ustc.edu.cn/nix-channels/nixos-25.11/nixexprs.tar.xz";
  };
  imports = [
    # Hardware modules
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./hardware-configuration.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/server.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  boot.kernelParams = [ "console=ttyS0,115200n8" "panic=10" ];
  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };
  # Boot loader configuration for RPi4
  boot.loader = {
    generic-extlinux-compatible.enable = true;
    grub.enable = false;
  };

  environment.systemPackages = with pkgs; [ libraspberrypi raspberrypi-eeprom ];
  services.adguardhome.enable = true;
  programs.zsh.enable = true;

  # Optimize build time and storage
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    MaxRetentionSec=1week
  '';

  # Enable NetworkManager
  networking.networkmanager = {
    enable = true;
    dns = "none";
  };
  networking.nameservers = [ "9.9.9.11" "223.5.5.5" ];
  networking.firewall = {
    allowedTCPPorts = [ 53 80 443 3000 ];
    allowedUDPPorts = [ 53 1080 ];
  };

  users.users.${config.mainUser} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${config.mainUser}";
    extraGroups = [ "networkmanager" "wheel" ];
  };
  # ============================================================================
  # Hardware Configuration
  # ============================================================================
  # XXX: 强状态依赖 - 使用mkForce覆盖硬件配置，依赖于SD卡标签"NIXOS_SD"和"FIRMWARE"存在
  # File system configuration based on current labels
  fileSystems = {
    "/" = lib.mkForce {
      device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
      options = [ "noatime" "commit=60" ];
    };
    "/boot" = lib.mkForce {
      device = "/dev/disk/by-uuid/EE9C-5155";
      fsType = "vfat";
    };
  };
}
