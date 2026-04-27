{ config, pkgs, lib, ... }: {
  boot.kernelParams = [ "preempt=voluntary" ];
  boot.kernel.sysctl = {
    # ipv6 privacy
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 0;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 0;
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
