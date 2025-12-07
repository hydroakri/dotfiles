{ config, pkgs, ... }:
let
  leanSnapperPolicy = {
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = "3";
    TIMELINE_LIMIT_DAILY = "3";
    TIMELINE_LIMIT_WEEKLY = "1";
    TIMELINE_LIMIT_MONTHLY = "0";
    TIMELINE_LIMIT_YEARLY = "1";
    ALLOW_USERS = [ config.mainUser ];
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
    configs = { home = leanSnapperPolicy // { SUBVOLUME = "/home"; }; };
  };

}
