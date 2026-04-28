{
  config,
  pkgs,
  lib,
  ...
}:
{
  boot.kernelParams = [ "preempt=voluntary" ];
  boot.kernel.sysctl = {
    # IPv6 privacy extensions for servers (stable/static preferred)
    "net.ipv6.conf.all.use_tempaddr" = lib.mkOverride 40 0;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkOverride 40 0;
    
    # optimize bufferbloat
    "net.core.netdev_max_backlog" = lib.mkDefault 2000;
    "net.core.rmem_max" = lib.mkDefault 4194304;
    "net.core.wmem_max" = lib.mkDefault 4194304;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 4194304";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 87380 4194304";
    "net.ipv4.tcp_mem" = lib.mkDefault "4194304 4194304 4194304";
  };
  services.irqbalance.enable = true;
  services.fail2ban.enable = true;
  services.tuned.enable = true;
  environment.etc."tuned/active_profile".text = ''
    throughput-performance
  '';
  environment.etc."tuned/profile_mode".text = ''
    manual
  '';
}
