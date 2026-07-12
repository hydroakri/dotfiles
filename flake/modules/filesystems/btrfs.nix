{ config, pkgs, ... }:
let
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
  environment.systemPackages = [ pkgs.btrfs-assistant ];
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    # preservation 开启时（tmpfs-on-root）"/" 不再是 btrfs，改用 /nix 触发
    # 同一个 btrfs 文件系统的 scrub（任意子卷挂载点都可以）
    fileSystems = [ (if config.modules.preservation.enable or false then "/nix" else "/") ];
  };
  systemd = {
    services.btrfs-balance = {
      description = "Smart Btrfs balance";
      requires = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
      unitConfig.ConditionACPower = true;
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        ExecStart = pkgs.writeShellScript "smart-balance" ''
          set -e
          echo "Starting smart Btrfs balance..."
          ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=0 -musage=0 ${if config.modules.preservation.enable or false then "/nix" else "/"} || true
          ${pkgs.btrfs-progs}/bin/btrfs balance start -musage=30 ${if config.modules.preservation.enable or false then "/nix" else "/"} || true
          ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=10 ${if config.modules.preservation.enable or false then "/nix" else "/"} || true
          echo "Balance complete. SSD remains happy."
        '';
      };
    };
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
    snapshotInterval = "hourly";
    cleanupInterval = "8h";
    configs = {
      home = leanSnapperPolicy // {
        SUBVOLUME = "/home";
      };
    }
    // {
      # preservation 开启时 "/" 变成 tmpfs，改盯 /persistent
      ${if config.modules.preservation.enable or false then "persistent" else "rootdir"} =
        leanSnapperPolicy
        // {
          SUBVOLUME = if config.modules.preservation.enable or false then "/persistent" else "/";
        };
    };
  };

  # 降低 Snapper 相关服务的优先级，防止抢占桌面资源
  systemd.services.snapper-timeline-cleanup = {
    serviceConfig = {
      IOWeight = 1;
      CPUWeight = 1;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  systemd.services.snapper-timeline-create = {
    serviceConfig = {
      IOWeight = 1;
      CPUWeight = 1;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

}
