{ config, lib, pkgs, ... }: {
  boot.kernelParams = ([
    # performance
    "lru_gen_enabled=1"
    "zswap.enabled=0"
    "transparent_hugepage=madvise"
    "nouveau.config=NvBoost=2"
    "nouveau.modeset=1"
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64
    [ "processor.ignore_ppc=1" ]);
  # CPU microcode (common)
  hardware.cpu.amd.updateMicrocode =
    lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 true;
  hardware.cpu.intel.updateMicrocode =
    lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 true;
  boot.kernel.sysctl = {
    # Network (common)
    "net.core.default_qdisc" = "cake";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_low_latency" = 1;
    "net.ipv4.tcp_timestamps" = 0;
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
    "vm.swappiness" = 100;
    "vm.dirty_ratio" = 40;
    "vm.dirty_background_ratio" = 10;
    "vm.page-cluster" = 0;
    "vm.nr_hugepages" = 0;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_writeback_centisecs" = 1500;
    "vm.dirty_expire_centisecs" = 1500;
    "vm.min_free_kbytes" = 65536;
    "vm.max_map_count" = 262144;
  };
  services.udev.extraRules = ''
    # NVMe SSD: 设置为 none
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ENV{DEVTYPE}=="disk", ATTR{queue/scheduler}="none"

    # SATA SSD / eMMC: 设置为 mq-deadline
    ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

    # 旋转硬盘 HDD: 设置为 bfq
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
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
  services.fwupd.enable = true;
  services.fstrim.enable = true;
  services.earlyoom.enable = true;
  systemd.oomd.enable = false;
  services.scx = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
    enable = true;
    scheduler = "scx_rusty";
  };

}
