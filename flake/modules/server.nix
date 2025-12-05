{ config, pkgs, ... }: {
  boot.kernelParams = [ "preempt=voluntary" ];
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
