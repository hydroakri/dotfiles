{
  config,
  lib,
  ...
}:
{
  boot.kernelParams = [ "preempt=voluntary" ];
  networking.tempAddresses = lib.mkOverride 900 "disabled";
  boot.kernel.sysctl = {
    # networking.tempAddresses only drives *.default.use_tempaddr; .all isn't
    # covered by that option, so it still needs a direct assignment here.
    "net.ipv6.conf.all.use_tempaddr" = lib.mkOverride 900 0;

    # optimize bufferbloat
    "net.core.netdev_max_backlog" = lib.mkDefault 2000;
    "net.core.rmem_max" = lib.mkDefault 4194304;
    "net.core.wmem_max" = lib.mkDefault 4194304;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 4194304";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 87380 4194304";
    "net.ipv4.tcp_mem" = lib.mkDefault "4194304 4194304 4194304";
    "net.core.netdev_budget" = lib.mkDefault 600;
    "net.core.netdev_budget_usecs" = lib.mkDefault 8000;
  };
  services.irqbalance.enable = lib.mkDefault true;
  services.fail2ban.enable = lib.mkDefault true;
  services.tuned.enable = lib.mkDefault true;
  environment.etc."tuned/active_profile".text = lib.mkDefault "throughput-performance";
  environment.etc."tuned/profile_mode".text = lib.mkDefault "manual";
}
