# nixos-rebuild boot --flake .#rpi4 --target-host root@192.168.1.4 --install-bootloader
# nh os switch -H rpi4 ./
{ config, lib, pkgs, inputs, ... }: {
  networking.hostName = "rpi4";
  nixpkgs.system = "aarch64-linux";
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

  # Boot loader configuration for RPi4
  boot.loader = {
    generic-extlinux-compatible.enable = true;
    grub.enable = false;
  };
  boot.plymouth.enable = false;
  # boot.kernelPackages = lib.mkForce pkgs.linuxPackages_rpi4;
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  boot.initrd.supportedFilesystems = [ "vfat" "ext4" ];
  boot.initrd.kernelModules = [
    "usbhid"
    "usb_storage"
    "vc4"
    "pcie-brcmstb" # RPi4 USB 控制器关键驱动
    "reset-raspberrypi"
    "mmc_block" # 识别为存储设备
    "sdhci_iproc" # RPi4 SD控制器驱动
    "bcm2835_dma" # DMA 加速
  ];

  hardware = {
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };

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
  environment.systemPackages = with pkgs; [ libraspberrypi raspberrypi-eeprom ];
  programs.zsh.enable = true;
  services.adguardhome.enable = true;
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    MaxRetentionSec=1week
  '';

  users.users.${config.mainUser} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "${config.mainUser}";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  boot.kernel.sysfs = {
    class.leds = {
      # 关闭绿色活动灯 (ACT)
      ACT = {
        trigger = "none";
        brightness = 0;
      };

      # 关闭红色电源灯 (PWR)
      PWR = {
        trigger = "none";
        brightness = 0;
      };
      "unimac-mdio--19:01:amber:lan" = {
        trigger = "none";
        brightness = 0;
      };
      "unimac-mdio--19:01:green:lan" = {
        trigger = "none";
        brightness = 0;
      };
    };
  };
  # ============================================================================
  # Hardware Configuration
  # config.txt
  # gpio=42=ip,pd
  # dtparam=eth_led0=4
  # dtparam=eth_led1=4
  # dtparam=pwr_led_trigger=none
  # dtparam=pwr_led_activelow=off
  # dtparam=act_led_trigger=none
  # dtparam=act_led_activelow=off
  # max_usb_current=1
  # hdmi_group=2
  # hdmi_mode=87
  # hdmi_cvt 800 480 60 6 0 0 0
  # hdmi_drive=1
  # config_hdmi_boost=7
  # hdmi_ignore_edid=0xa5000080
  # ============================================================================
  # XXX: INSTALLATION
  # File system configuration based on current labels
  fileSystems = {
    "/" = lib.mkForce {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "commit=60" ];
    };
  };
}
