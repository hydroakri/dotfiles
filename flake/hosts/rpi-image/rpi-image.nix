# nix build '.#packages.aarch64-linux.rpi-image'
{ config, lib, pkgs, inputs, ... }: {
  # Boot configuration
        boot.loader = {
          generic-extlinux-compatible.enable = true;
          grub.enable = false;
        };
        sdImage = {
          compressImage = true;
          firmwareSize = 512;
        };
        system.stateVersion = "25.11";
        nixpkgs.system = "aarch64-linux";
        nixpkgs.config.allowUnfree = true;

        # Hardware configuration
        hardware = {
          enableRedistributableFirmware = true;
          deviceTree = {
            enable = true;
            filter = "*-rpi-4-*.dtb";
          };
        };
        boot.kernelPackages = lib.mkForce pkgs.linuxPackages_rpi4;
        boot.initrd.availableKernelModules = lib.mkForce [
          "usbhid"
          "usb_storage"
          "vc4"
          "pcie-brcmstb" # RPi4 USB 控制器关键驱动
          "reset-raspberrypi"
          "mmc_block" # 识别为存储设备
          "sdhci_iproc" # RPi4 SD控制器驱动
          "bcm2835_dma" # DMA 加速
        ];
        boot.kernelParams = [
          "console=ttyS0,115200n8"
          "console=tty0"
          "cma=128M" # 显存分配，防止 GUI 卡死
        ];

        networking = {
          hostName = "rpi-image";
          wireless = {
            enable = true;
            networks."example".psk = "1234567890";
          };
        };
        environment.systemPackages = with pkgs; [
          libraspberrypi
          raspberrypi-eeprom
          vim
          git
        ];

        # Basic services
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "yes";
          settings.PasswordAuthentication = true;
        };

        users.users.root.initialPassword = "root";
        # users.users.root.openssh.authorizedKeys.keys = [ ];

        # Basic firewall
        networking.firewall.enable = true;
        networking.firewall.allowedTCPPorts = [ 22 ];
}
