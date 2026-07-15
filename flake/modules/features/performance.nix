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
        "rcupdate.rcu_normal_after_boot=1"
      ]
      ++ lib.optionals (!((config.modules.powersave or { }).enable or false)) [
        "skew_tick=1"
      ]
      # 当 modules.powersave.enable 开启时，不设置 ignore_ppc (避免忽略固件功耗限制)
      ++
        lib.optionals
          (pkgs.stdenv.hostPlatform.isx86_64 && !((config.modules.powersave or { }).enable or false))
          [
            "processor.ignore_ppc=1"
          ]
    );
    # CPU microcode (vendor-specific via modules.performance.vendor)
    hardware.cpu.amd.updateMicrocode = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
      config.modules.performance.vendor == "amd"
    );
    hardware.cpu.intel.updateMicrocode = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
      config.modules.performance.vendor == "intel"
    );
    boot.kernel.sysctl = {
      # Network (common)
      "net.core.default_qdisc" = lib.mkOverride 950 "cake";
      "net.ipv4.tcp_congestion_control" = lib.mkOverride 950 "bbr";
      "net.ipv4.tcp_low_latency" = lib.mkOverride 950 1;
      # mkOverride 900: intentionally overrides security.nix's mkDefault 0
      # (TCP timestamps traded for performance here); still yields to a plain
      # user assignment, unlike a bare literal which would hard-conflict.
      "net.ipv4.tcp_timestamps" = lib.mkOverride 900 1;
      "net.ipv4.tcp_fastopen" = lib.mkOverride 950 3;
      "net.core.somaxconn" = lib.mkOverride 950 4096;
      "net.core.netdev_max_backlog" = lib.mkOverride 950 2048;
      "net.core.rmem_max" = lib.mkOverride 950 16777216;
      "net.core.wmem_max" = lib.mkOverride 950 16777216;
      "net.core.optmem_max" = lib.mkOverride 950 65536;
      "net.ipv4.tcp_rmem" = lib.mkOverride 950 "4096 87380 16777216";
      "net.ipv4.tcp_wmem" = lib.mkOverride 950 "4096 65536 16777216";
      "net.ipv4.udp_rmem_min" = lib.mkOverride 950 8192;
      "net.ipv4.udp_wmem_min" = lib.mkOverride 950 8192;
      "net.ipv4.tcp_max_syn_backlog" = lib.mkOverride 950 8192;
      "net.ipv4.tcp_max_tw_buckets" = lib.mkOverride 950 2000000;
      "net.ipv4.tcp_tw_reuse" = lib.mkOverride 950 1;
      "net.ipv4.tcp_fin_timeout" = lib.mkOverride 950 20;
      "net.ipv4.tcp_slow_start_after_idle" = lib.mkOverride 950 0;
      "net.ipv4.tcp_keepalive_time" = lib.mkOverride 950 60;
      "net.ipv4.tcp_keepalive_intvl" = lib.mkOverride 950 10;
      "net.ipv4.tcp_keepalive_probes" = lib.mkOverride 950 6;
      "net.ipv4.tcp_mtu_probing" = lib.mkOverride 950 1;
      "net.ipv4.tcp_sack" = lib.mkOverride 950 1;
      "net.ipv4.tcp_adv_win_scale" = lib.mkDefault (-2);
      "net.ipv4.tcp_notsent_lowat" = lib.mkDefault 16384;
      "net.netfilter.nf_conntrack_max" = lib.mkOverride 950 1048576;
      "net.netfilter.nf_conntrack_tcp_timeout_established" = lib.mkOverride 950 120;

      # optimize ipv6
      "net.ipv6.conf.all.accept_ra" = lib.mkOverride 950 2;
      "net.ipv6.conf.default.accept_ra" = lib.mkOverride 950 2;

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
      "vm.stat_interval" = lib.mkDefault 10;
      "kernel.hung_task_timeout_secs" = lib.mkDefault 600;
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
    boot.tmp.useTmpfs = lib.mkDefault true;
    services.zram-generator = {
      enable = lib.mkDefault true;
      settings = {
        "zram0" = {
          "zram-size" = "ram/2";
          "compression-algorithm" = "zstd";
        };
      };
    };
    hardware.ksm.enable = lib.mkDefault true;
    services.fwupd.enable = lib.mkDefault true;
    services.fstrim.enable = lib.mkDefault true;
    services.earlyoom = {
      enable = lib.mkDefault true;
      freeMemThreshold = lib.mkDefault 5;
      freeSwapThreshold = lib.mkDefault 5;
      extraArgs = [
        # 保护游戏/Wine/Proton 进程不被 earlyoom 误杀
        "--avoid"
        "(^|/)(exe|steam|wine|gamescope|mangohud|proton)"
      ];
    };
    systemd.oomd.enable = lib.mkDefault false;
    services.scx = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
      enable = lib.mkDefault true;
      scheduler = lib.mkDefault "scx_rusty";
    };
    # Process priority optimization (desktop only — cachyos rules target interactive workloads)
    services.ananicy = lib.mkIf config.services.displayManager.enable {
      enable = lib.mkDefault true;
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
