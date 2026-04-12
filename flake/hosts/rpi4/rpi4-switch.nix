# nixos-rebuild boot --flake .#rpi4 --target-host root@192.168.1.4 --install-bootloader |& nom
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
    ../../modules/features/utils.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    # 关闭所有代理模块，恢复为纯净路由器
    modules = {
      proxy = {
        enable = false;
        enableAdGuardHome = false;
        enableDnsCryptProxy = false;
        enableSingbox = false;
        enableDae = false;
      };
      utils = {
        enable = false;
        enableGlance = false;
        enableGrafana = false;
        enablePrometheus = false;
        enableGraphicTools = false;
      };
    };

    networking.hostName = "rpi4";
    nixpkgs.system = "aarch64-linux";
    # Boot loader configuration for RPi4
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
    boot.kernel.sysctl = {
      # 开启内核转发，允许局域网流量访问外网
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.default.forwarding" = 1;

      # optimize bufferbloat
      "net.core.netdev_max_backlog" = lib.mkForce 2000;
      "net.core.rmem_max" = lib.mkForce 4194304;
      "net.core.wmem_max" = lib.mkForce 4194304;
      "net.ipv4.tcp_rmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_wmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_mem" = lib.mkForce "4194304 4194304 4194304";
    };
    boot.kernel.sysfs = {
      # enable net card RPS & XPS
      class.net.end0.queues."rx-0".rps_cpus = "f";

      class.net.wlan0.queues."rx-0".rps_cpus = "f";
      class.net.wlan0.queues."tx-0".xps_cpus = "f";
    };
    powerManagement.cpuFreqGovernor = "performance";
    environment.etc."tuned/active_profile".text = lib.mkForce "network-latency";
    services.irqbalance.enable = lib.mkForce false;

    networking.networkmanager.unmanaged = [ "end0" "vlan10" "wlan0" ];
    networking.wireless.enable = lib.mkForce false;

    # 1. 物理网卡与 VLAN 10 设置 (WAN口 / 光纤直连)
    networking.vlans = {
      vlan10 = {
        id = 10;
        interface = "end0";
      };
    };
    networking.interfaces.end0.useDHCP = false;
    networking.interfaces.vlan10.useDHCP = true; # DHCP 获取外网 IP (IPoE免密)
    # 2. 局域网接口 (wlan0) 强制固定 IP
    networking.interfaces.wlan0.useDHCP = false;
    networking.interfaces.wlan0.ipv4.addresses = lib.mkForce [{
      address = "192.168.10.1";
      prefixLength = 24;
    }];
    # 3. NAT 流量伪装 (把手机的流量伪装成光纤接口的流量)
    networking.nat = {
      enable = true;
      externalInterface = "vlan10";
      internalInterfaces = [ "wlan0" ];
    };
    # 4. 防火墙完全放行局域网
    networking.firewall = {
      enable = true;
      trustedInterfaces = [ "wlan0" ];
    };

    services.hostapd = {
      enable = true;
      radios.wlan0 = {
        band = "2g";
        channel = 6;
        countryCode = "NZ";

        wifi4.enable = true;

        networks.wlan0 = {
          ssid = "RPi4_WIFI";
          authentication = {
            mode = "wpa2-sha1";
            wpaPassword = "1234567890"; # 请修改密码
          };
        };
      };
    };

    # 6. 配置 DHCP 和 DNS 服务 (dnsmasq) 
    services.resolved.enable = lib.mkForce false;
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        interface = "wlan0";
        bind-dynamic = true;
        dhcp-range = "192.168.10.10,192.168.10.100,24h";
        port = 53;
        domain-needed = true;
        bogus-priv = true;
        server = [ "172.64.36.2" "149.112.112.11" ];
      };
    };

    # 【修复启动过快崩溃】确保网卡 IP 准备就绪后再运行 dnsmasq
    systemd.services.dnsmasq = {
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
      after = [ "network.target" "hostapd.service" ];
      wants = [ "hostapd.service" ];
    };

    # ============================================================================
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

    users.users.${config.mainUser} = {
      shell = pkgs.zsh;
      isNormalUser = true;
      description = "${config.mainUser}";
      extraGroups = [ "networkmanager" "wheel" ];
    };

    fileSystems = {
      "/" = lib.mkForce {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = [ "noatime" "commit=60" ];
      };
    };
  };
}
