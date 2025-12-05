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
    ../../modules/features/security.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200n8" "panic=10" ];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
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
  time.timeZone = "Australia/Perth";
  networking.networkmanager.enable = true;
  networking.firewall = {
    allowedTCPPorts = [ 53 80 443 3000 ];
    allowedUDPPorts = [ 53 1080 ];
  };

  users.users.hydroakri = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "hydroakri";
    extraGroups = [ "networkmanager" "wheel" ];
  };
  # ============================================================================
  # Hardware Configuration
  # ============================================================================
  # File system configuration based on current labels
  fileSystems = {
    "/" = lib.mkForce {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "commit=120" ];
    };
    "/boot" = lib.mkForce {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
    };
  };
}
