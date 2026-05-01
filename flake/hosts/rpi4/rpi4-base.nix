{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.loader = {
    generic-extlinux-compatible.enable = true;
    grub.enable = false;
  };
  boot.plymouth.enable = false;
  boot.kernelPackages = pkgs.linuxPackages;
  boot.initrd.supportedFilesystems = [
    "vfat"
    "ext4"
  ];
  console.font = "ter-v16n";
  boot.initrd.kernelModules = [
    "usbhid"
    "usb_storage"
    "vc4"
    "pcie-brcmstb"
    "reset-raspberrypi"
    "mmc_block"
    "sdhci_iproc"
    "bcm2835_dma"
  ];

  powerManagement.cpuFreqGovernor = "performance";
  environment.etc."tuned/active_profile".text = "network-latency";
  services.irqbalance.enable = false;

  hardware = {
    raspberry-pi."4" = {
      apply-overlays-dtmerge.enable = true;
      leds = {
        eth.disable = true;
        act.disable = true;
        pwr.disable = true;
      };
    };
    deviceTree = {
      enable = true;
      filter = "*-rpi-4-*.dtb";
    };
  };

  environment.systemPackages = [
    pkgs.libraspberrypi
    pkgs.raspberrypi-eeprom
    pkgs.ethtool
  ];
  services.smartd.enable = false;
  services.journald.extraConfig = ''
    Storage=volatile
    SystemMaxUse=64M
    MaxRetentionSec=1week
  '';

  fileSystems = {
    "/" = lib.mkForce {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [
        "noatime"
        "commit=60"
      ];
    };
  };

  system.stateVersion = "25.11";
}
