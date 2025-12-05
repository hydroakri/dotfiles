{ config, lib, pkgs, ... }: {
  boot.kernelParams = [
    "mitigations=auto"
    "random.trust_cpu=0"
    "lsm=landlock,lockdown,yama,integrity,apparmor,bpf"
    "lockdown=integrity"
  ];
  boot.kernel.sysctl = {
    # Security (common)
    "kernel.core_pattern" = "|/bin/false";
    "kernel.unprivileged_bpf_disabled" = 1;
    "module.sig_enforce" = 1;
    "kernel.printk_devkmsg" = "off";
  };
  security = {
    sudo-rs.enable = true;
    sudo.enable = false;
    apparmor.enable = true;
  };
  services.openssh.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

}
