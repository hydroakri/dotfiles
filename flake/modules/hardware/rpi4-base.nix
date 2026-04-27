{ config, lib, pkgs, ... }:

{
  boot.loader = {
    generic-extlinux-compatible.enable = true;
    grub.enable = false;
  };
  boot.plymouth.enable = false;
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
  boot.initrd.supportedFilesystems = [ "vfat" "ext4" ];
  console.font = lib.mkForce "ter-v16n";
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
  environment.etc."tuned/active_profile".text = lib.mkForce "network-latency";
  services.irqbalance.enable = lib.mkForce false;

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

  systemd.services.fake-hwclock = {
    description = "Restore system time on boot (Fake Hardware Clock)";
    wantedBy = [ "sysinit.target" ];
    before = [ "sysinit.target" "chronyd.service" ];
    after = [ "local-fs.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "restore-time" ''
        if [ -f /var/lib/fake-hwclock ]; then
          echo "Restoring time from /var/lib/fake-hwclock..."
          ${pkgs.coreutils}/bin/date -s "$(cat /var/lib/fake-hwclock)" || true
        else
          echo "No saved time found, forcing default..."
          ${pkgs.coreutils}/bin/date -s "2025-11-01 00:00:00" || true
        fi
      '';
      ExecStop = pkgs.writeShellScript "save-time" ''
        ${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S' > /var/lib/fake-hwclock
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
    ethtool
  ];
  services.smartd.enable = lib.mkForce false;
  services.journald.extraConfig = ''
    Storage=volatile
    SystemMaxUse=64M
    MaxRetentionSec=1week
  '';


  fileSystems = {
    "/" = lib.mkForce {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" "commit=60" ];
    };
  };

  system.stateVersion = "25.11";
}
