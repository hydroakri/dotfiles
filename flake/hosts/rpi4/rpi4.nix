# nixos-rebuild boot --flake .#rpi4 --target-host root@192.168.1.4 --install-bootloader
# nh os switch -H rpi4 ./
{ config, lib, pkgs, inputs, ... }: {
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
    ../../modules/features/proxy.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];
  options.services.dae.config = lib.mkOption {
    apply = finalConfig:
      if finalConfig == null then
        null
      else
        builtins.replaceStrings [
          "lan_interface: auto"
          "wan_interface: auto"
        ] # 前面：要被替换掉的原始值（需与 proxy.nix 完全一致）
        [ "lan_interface: end0" "wan_interface: end0" ] # 后面：你想要的新值
        finalConfig;
  };

  config = {
    modules.proxy = {
      enable = true;
      enableDnsCryptProxy = false;
      enableDae = true;
      enableSingbox = true;
    };

    networking.hostName = "rpi4";
    nixpkgs.system = "aarch64-linux";
    # Boot loader configuration for RPi4
    boot.loader = {
      generic-extlinux-compatible.enable = true;
      grub.enable = false;
    };
    boot.plymouth.enable = false;
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_rpi4;
    # boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
    boot.initrd.supportedFilesystems = [ "vfat" "ext4" ];
    console.font = lib.mkForce "ter-v16n";
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
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;

      # optimize bufferbloat
      "net.core.netdev_max_backlog" = lib.mkForce 2000;
      "net.core.rmem_max" = lib.mkForce 4194304;
      "net.core.wmem_max" = lib.mkForce 4194304;
      "net.ipv4.tcp_rmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_wmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_mem" = lib.mkForce "4194304 4194304 4194304";
    };
    powerManagement.cpuFreqGovernor = "performance";
    environment.etc."tuned/active_profile".text = lib.mkForce "network-latency";
    services.irqbalance.enable = lib.mkForce false; # 禁用自动平衡
    boot.kernel.sysfs = {
      # enable net card RPS
      class.net.end0.queues."rx-0".rps_cpus = "f";
    };
    networking.interfaces.end0.mtu = 1492;
    systemd.services.network-optimization = {
      description = "Apply Network Optimizations (Ethtool, TC, MSS)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "optimize-network" ''
          # A. 关闭网卡卸载 (解决微突发抖动，让 RPi4 CPU 接管分包)
          ${pkgs.ethtool}/bin/ethtool -K end0 gso off tso off gro on
          # 1. 清除旧规则
          ${pkgs.iproute2}/bin/tc qdisc del dev end0 root 2>/dev/null || true
          # 2. 应用新规则：
          # TODO bandwidth change depend on current network
          ${pkgs.iproute2}/bin/tc qdisc add dev end0 root cake bandwidth 370mbit besteffort nat
          #    确保 SS-2022 加密后的包不会撑爆 MTU
          ${pkgs.iptables}/bin/iptables -t mangle -A POSTROUTING -o end0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1412
        '';
      };
    };

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
    networking.nameservers = [ "127.0.0.1" "172.64.36.2" ];
    networking.firewall = {
      allowedTCPPorts = [
        # adguardhome
        53
        80
        443
        3000
        # singbox
        1080
        9090
      ];
      allowedUDPPorts = [
        #adguardhome
        53
        1080
        # DHCP
        67
        68
        547
        546
      ];
      checkReversePath = false; # For dae transparent netgate
    };
    environment.systemPackages = with pkgs; [
      libraspberrypi
      raspberrypi-eeprom
      ethtool
    ];
    programs.zsh.enable = true;
    services.adguardhome.enable = true;
    systemd.services.adguardhome.serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
    };
    services.journald.extraConfig = ''
      Storage=volatile
      SystemMaxUse=64M
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
        ACT = {
          trigger = "none";
          brightness = 0;
        };
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
  };
}
