{ config, lib, pkgs, ... }: {
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.plymouth.enable = true;
  boot.kernelParams = lib.mkDefault [
    # boot screen
    "quiet"
    "splash"
    "loglevel=3"
    "rd.udev.log_level=3"
    "vt.global_cursor_default=0"
    "rd.systemd.show_status=auto"
    # battery
    "nowatchdog"
    "nmi_watchdog=0"
    "mem_sleep_default=s2idle"
    "radeon.dpm=1"
    "amd_pstate=active"
    "intel_pstate=active"
    "iwlwifi.power_save=1"
    "nouveau.config=NvGspRm=1"
  ];
  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.laptop_mode" = 5;
  };
  powerManagement.cpuFreqGovernor =
    "powersave"; # active 模式下 powersave 实际上是将控制权交给固件
  services.udev.extraRules = ''
    # 电源控制
    SUBSYSTEM=="pci", ATTR{power/control}="auto"
  '';
  # services.auto-cpufreq.enable = true;
  services.power-profiles-daemon.enable = true;
  environment.systemPackages = with pkgs; [ nbfc-linux ];
  networking.interfaces.wlo1.wakeOnLan.enable = false;
  networking.interfaces.eno1.wakeOnLan.enable = false;
  networking.networkmanager.wifi.powersave = true;
  # nbfc-linux fancontrol
  systemd.services.nbfc_service = {
    enable = true;
    description = "NoteBook FanControl service";
    serviceConfig.Type = "simple";
    path = [ pkgs.kmod ];
    script = "${pkgs.nbfc-linux}/bin/nbfc_service -c /etc/nixos/nbfc.json";
    wantedBy = [ "multi-user.target" ];
  };
}
