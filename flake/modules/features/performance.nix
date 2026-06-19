{
  config,
  lib,
  pkgs,
  ...
}:
let
  zswapDisable = pkgs.writeShellScript "zswap-disable" ''
    echo N > /sys/module/zswap/parameters/enabled
  '';
in
{
  options.modules.performance.vendor = lib.mkOption {
    type = lib.types.enum [
      "amd"
      "intel"
      "other"
    ];
    default = "other";
    description = "CPU vendor for microcode and pstate kernel params";
  };

  config = {
    boot.kernelParams = (
      [
        # performance
        "lru_gen_enabled=1"
        "zswap.enabled=0"
        "transparent_hugepage=madvise"
      ]
      # 当 modules.powersave.enable 开启时，不设置 ignore_ppc (避免忽略固件功耗限制)
      ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64 && !config.modules.powersave.enable) [
        "processor.ignore_ppc=1"
      ]
    );
    # CPU microcode (vendor-specific via modules.performance.vendor)
    hardware.cpu.amd.updateMicrocode = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (config.modules.performance.vendor == "amd");
    hardware.cpu.intel.updateMicrocode = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (config.modules.performance.vendor == "intel");
    boot.kernel.sysctl = {
      # Network (common)
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.ipv4.tcp_low_latency" = 1;
      "net.ipv4.tcp_timestamps" = 1;
      "net.ipv4.tcp_fastopen" = 3;
      "net.core.somaxconn" = 4096;
      "net.core.netdev_max_backlog" = 2048;
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.core.optmem_max" = 65536;
      "net.ipv4.tcp_rmem" = "4096 87380 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";
      "net.ipv4.udp_rmem_min" = 8192;
      "net.ipv4.udp_wmem_min" = 8192;
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.ipv4.tcp_max_tw_buckets" = 2000000;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_fin_timeout" = 20;
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_keepalive_time" = 60;
      "net.ipv4.tcp_keepalive_intvl" = 10;
      "net.ipv4.tcp_keepalive_probes" = 6;
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_sack" = 1;
      "net.netfilter.nf_conntrack_max" = 1048576;
      "net.netfilter.nf_conntrack_tcp_timeout_established" = 120;

      # optimize ipv6
      "net.ipv6.conf.all.accept_ra" = 2;
      "net.ipv6.conf.default.accept_ra" = 2;

      # VM (common)
      "vm.swappiness" = lib.mkDefault 180;
      "vm.dirty_bytes" = lib.mkDefault 268435456; # 256MB (≈RAM/64, for ~16GB)
      "vm.dirty_background_bytes" = lib.mkDefault 134217728; # 128MB (≈RAM/128)
      "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
      "vm.dirty_expire_centisecs" = lib.mkDefault 1500;
      "vm.watermark_boost_factor" = lib.mkDefault 0;
      "vm.watermark_scale_factor" = lib.mkDefault 125;
      "vm.compaction_proactiveness" = lib.mkDefault 0;
      "kernel.split_lock_mitigate" = lib.mkDefault 0;
      "vm.page-cluster" = lib.mkDefault 0;
      "vm.nr_hugepages" = lib.mkDefault 0;
      "vm.vfs_cache_pressure" = lib.mkDefault 50;
      "vm.min_free_kbytes" = lib.mkDefault 65536;
      "vm.max_map_count" = lib.mkOverride 900 1048576;
      "fs.inotify.max_user_instances" = lib.mkOverride 900 1024;
    };
    services.udev.extraRules = ''
      # NVMe SSD: kyber 提供延迟隔离
      ACTION=="add|change", KERNEL=="nvme[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="kyber"

      # SATA SSD / eMMC: 设置为 mq-deadline
      ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

      # 旋转硬盘 HDD: 设置为 bfq
      ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

      # Prevent bumb noise
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"

      # HDD Performance Tuning to rotational disks.
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
      ATTRS{id/bus}=="ata", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 0 /dev/%k"

      # When used with ZRAM, it is better to prefer page out only anonymous pages
      ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", RUN+="${zswapDisable}"
    '';
    boot.tmp.useTmpfs = true;
    services.zram-generator = {
      enable = true;
      settings = {
        "zram0" = {
          "zram-size" = "ram/2";
          "compression-algorithm" = "zstd";
        };
      };
    };
    hardware.ksm.enable = true;
    services.fwupd.enable = true;
    services.fstrim.enable = true;
    services.earlyoom.enable = true;
    systemd.oomd.enable = false;
    services.scx = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
      enable = lib.mkDefault true;
      scheduler = lib.mkDefault "scx_rusty";
    };
    # Process priority optimization (desktop only — cachyos rules target interactive workloads)
    services.ananicy = lib.mkIf config.services.displayManager.enable {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };
    services.journald.extraConfig = lib.mkDefault ''
      SystemMaxUse=64M
    '';
    environment.systemPackages = [
      pkgs.hdparm # udev rules require hdparm
    ];
  };
}
