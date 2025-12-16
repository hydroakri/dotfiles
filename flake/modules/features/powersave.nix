{ config, lib, pkgs, ... }: {
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.plymouth.enable = true;
  boot.kernelParams = [
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
    # To hide any kernel messages from the console
    "kernel.printk" = "3 3 3 3";
  };
  powerManagement.cpuFreqGovernor =
    "powersave"; # active 模式下 powersave 实际上是将控制权交给固件
  services.udev.extraRules = ''
    # 电源控制
    SUBSYSTEM=="pci", ATTR{power/control}="auto"

    # Disables power saving capabilities for snd-hda-intel when device is not
    # running on battery power. This is needed because it prevents audio cracks on
    # some hardware.
    ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", \
        RUN+="${pkgs.bash}/bin/bash -c 'touch /run/udev/snd-hda-intel-powersave; \
            [[ $$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) != \"Discharging\" ]] && \
            echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave && \
            echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"

    SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", \
        RUN+="${pkgs.bash}/bin/bash -c 'echo $$(cat /run/udev/snd-hda-intel-powersave 2>/dev/null || \
            echo 10) > /sys/module/snd_hda_intel/parameters/power_save'"

    SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", \
        RUN+="${pkgs.bash}/bin/bash -c '[[ $$(cat /sys/module/snd_hda_intel/parameters/power_save) != 0 ]] && \
            echo $$(cat /sys/module/snd_hda_intel/parameters/power_save) > /run/udev/snd-hda-intel-powersave; \
            echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
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
