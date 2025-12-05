{ config, pkgs, ... }:
let
  leanSnapperPolicy = {
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    # Hourly: 仅保留最近 6 小时。
    # 解决了你担心的重叠问题：Hourly 不再延伸到"昨天"，只负责"当下"。
    TIMELINE_LIMIT_HOURLY = "6";
    # Daily: 保留 5 天 (工作周长度)。
    # 如果问题发生在6小时前，直接找当天的 Daily 或者昨天的 Daily。
    TIMELINE_LIMIT_DAILY = "5";
    # Weekly: 保留 2 周。
    # 填补 Daily(5天) 和 Monthly 之间的空隙，防止断档。
    TIMELINE_LIMIT_WEEKLY = "2";
    # Monthly: 保留 1 个。
    TIMELINE_LIMIT_MONTHLY = "1";
    # Yearly: 1 个 (可选，如果磁盘紧张可设为 0)
    TIMELINE_LIMIT_YEARLY = "1";
    ALLOW_USERS = [ "hydroakri" ];
  };
in {
  environment.systemPackages = with pkgs; [ btrfs-assistant ];
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
  systemd = {
    services.btrfs-balance = {
      description = "Smart Btrfs balance";
      requires = [ "local-fs.target" ];
      after = [ "local-fs.target" ];
      unitConfig.ConditionACPower = true;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "smart-balance" ''
          set -e
          echo "Starting smart Btrfs balance..."
          ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=0 -musage=0 / || true
          ${pkgs.btrfs-progs}/bin/btrfs balance start -musage=30 / || true
          ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=10 / || true
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
    cleanupInterval = "1h";
    configs = {
      home = leanSnapperPolicy // { SUBVOLUME = "/home"; };
      varlog = leanSnapperPolicy // { SUBVOLUME = "/var/log"; };
    };
  };

}
