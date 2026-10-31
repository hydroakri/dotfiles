{
  config,
  lib,
  pkgs,
  ...
}:
let
  preserved = config.modules.preservation.enable or false;
  persistentPath = config.modules.preservation.persistentPath or "";
  # preservation 开启时 "/" 是 tmpfs，btrfs 实际挂在 /nix
  btrfsRoot = if preserved then "/nix" else "/";
  leanSnapperPolicy = {
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = "8";
    TIMELINE_LIMIT_DAILY = "4";
    TIMELINE_LIMIT_WEEKLY = "2";
    TIMELINE_LIMIT_MONTHLY = "1";
    TIMELINE_LIMIT_YEARLY = "0";
    ALLOW_USERS = [ config.mainUser ];
    # 关键：禁用配额计算，防止卡顿
    BACKGROUND_COMPARISON = "no";
  };
in
{
  imports = [ ../options.nix ];

  assertions = [
    {
      assertion = (config.fileSystems.${btrfsRoot}.fsType or null) == "btrfs";
      message = "filesystem-btrfs: fileSystems.\"${btrfsRoot}\" must be btrfs (scrub/balance target).";
    }
  ];

  environment.systemPackages = [ pkgs.btrfs-assistant ];
  services.btrfs.autoScrub = {
    enable = lib.mkDefault true;
    interval = lib.mkDefault "monthly";
    # preservation 开启时（tmpfs-on-root）"/" 不再是 btrfs，改用 /nix 触发
    # 同一个 btrfs 文件系统的 scrub（任意子卷挂载点都可以）
    fileSystems = [ btrfsRoot ];
  };
  systemd = {
    services = {
      btrfs-balance = {
        description = "Smart Btrfs balance";
        requires = [ "local-fs.target" ];
        after = [ "local-fs.target" ];
        unitConfig.ConditionACPower = true;
        serviceConfig = {
          Type = "oneshot";
          Nice = 19;
          IOSchedulingClass = "idle";
          ExecStart = pkgs.writeShellScript "smart-balance" ''
            echo "Starting smart Btrfs balance..."
            ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=0 -musage=0 ${btrfsRoot} || true
            ${pkgs.btrfs-progs}/bin/btrfs balance start -musage=30 ${btrfsRoot} || true
            ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=10 ${btrfsRoot} || true
            echo "Balance complete. SSD remains happy."
          '';
        };
      };
    }
    # 降低 Snapper 相关服务的优先级，防止抢占桌面资源
    // lib.genAttrs [ "snapper-timeline-cleanup" "snapper-timeline-create" ] (_: {
      serviceConfig = {
        IOWeight = 1;
        CPUWeight = 1;
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
      };
    });
    timers.btrfs-balance = {
      description = "Run smart btrfs balance monthly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
  services.snapper = {
    snapshotInterval = lib.mkDefault "hourly";
    cleanupInterval = lib.mkDefault "8h";
    configs = {
      home = leanSnapperPolicy // {
        SUBVOLUME = "/home";
      };
    }
    // {
      # preservation 开启时 "/" 变成 tmpfs，改盯 /persistent
      ${if preserved then "persistent" else "rootdir"} = leanSnapperPolicy // {
        SUBVOLUME = if preserved then persistentPath else "/";
      };
    };
  };
}
