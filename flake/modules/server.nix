{ config, pkgs, ... }: {
  boot.kernelParams = [ "preempt=voluntary" ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 40;
    "vm.dirty_background_ratio" = 10;
  };
  services.irqbalance.enable = true;
  services.tuned.enable = true;
  services.tuned.profile = "throughput-performance";
  services.fail2ban.enable = true;
}
