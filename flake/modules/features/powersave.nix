{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.powersave;

  sndHdaBattery = pkgs.writeShellScript "snd-hda-battery" ''
    echo 1 > /sys/module/snd_hda_intel/parameters/power_save
  '';

  sndHdaAc = pkgs.writeShellScript "snd-hda-ac" ''
    echo 0 > /sys/module/snd_hda_intel/parameters/power_save
  '';

  aspmBattery = pkgs.writeShellScript "aspm-battery" ''
    echo powersupersave > /sys/module/pcie_aspm/parameters/policy
  '';

  aspmAc = pkgs.writeShellScript "aspm-ac" ''
    echo powersave > /sys/module/pcie_aspm/parameters/policy
  '';

  amdgpuBattery = pkgs.writeShellScript "amdgpu-battery" ''
    shopt -s nullglob
    for dev in /sys/class/drm/card*/device; do
      driver_path="$dev/driver"
      if [ -L "$driver_path" ] && [ "$(basename "$(readlink "$driver_path")")" = "amdgpu" ]; then
        echo low > "$dev/power_dpm_force_performance_level" 2>/dev/null || true
        echo 3 > "$dev/pp_power_profile_mode" 2>/dev/null || true
      fi
    done
  '';

  amdgpuAc = pkgs.writeShellScript "amdgpu-ac" ''
    shopt -s nullglob
    for dev in /sys/class/drm/card*/device; do
      driver_path="$dev/driver"
      if [ -L "$driver_path" ] && [ "$(basename "$(readlink "$driver_path")")" = "amdgpu" ]; then
        echo auto > "$dev/power_dpm_force_performance_level" 2>/dev/null || true
        echo 1 > "$dev/pp_power_profile_mode" 2>/dev/null || true
      fi
    done
  '';
in
{
  options.modules.powersave = {
    enable = lib.mkEnableOption "powersave mode: battery-optimized kernel parameters, aggressive PCIe ASPM, and reduced wakeup sources for max s2idle efficiency";

    wakeOnLan.interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "wlo1"
        "eno1"
      ];
      description = "Interfaces to disable Wake-on-LAN on for power saving";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "rtc_cmos" ];
    boot.extraModprobeConfig = ''
      # Enable U-APSD for iwlwifi (deeper WiFi sleep)
      options iwlwifi uapsd_disable=0
    '';
    boot.consoleLogLevel = 3;
    boot.initrd.verbose = false;
    boot.kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
      "amd_pstate=active"
      "intel_pstate=active"
      "iwlwifi.power_save=1"
      "pcie_aspm=force" # close when there is issue with idle
      "pcie_port_pm=force" # close when there is issue with idle
      "nvme_core.default_ps_max_latency_us=25000"
      # PSR (Panel Self Refresh) disabled: amdgpu DMCUB firmware crashes on Cezanne with PSR enabled, causing display freeze
      # "amdgpu.dcfeaturemask=0x8"
      # Timer Events Oriented governor: better idle prediction for modern CPUs
      "cpuidle.governor=teo"
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      "mem_sleep_default=s2idle"
      "rtc_cmos.use_acpi_alarm=1"
    ];
    boot.kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;
      "vm.laptop_mode" = 5;
    };
    services.udev.extraRules = ''
      SUBSYSTEM=="pci", ATTR{power/control}="auto"

      # Disables snd-hda-intel power saving on AC (prevents audio crackling).
      # Restores it on battery.
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", \
          RUN+="${sndHdaBattery}"
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", \
          RUN+="${sndHdaAc}"

      # Dynamic PCIe ASPM policy: deepest L1.2 on battery, balanced L0s/L1 on AC.
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", \
          TEST=="/sys/module/pcie_aspm/parameters/policy", \
          RUN+="${aspmBattery}"
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", \
          TEST=="/sys/module/pcie_aspm/parameters/policy", \
          RUN+="${aspmAc}"

      # Dynamic AMD iGPU power state: low power on battery, auto on AC.
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", \
          RUN+="${amdgpuBattery}"
      SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", \
          RUN+="${amdgpuAc}"
    '';
    # services.auto-cpufreq.enable = true;
    services.power-profiles-daemon.enable = true;
    services.irqbalance.enable = lib.mkDefault true;
    networking.interfaces = lib.genAttrs cfg.wakeOnLan.interfaces (name: {
      wakeOnLan.enable = false;
    });
    networking.networkmanager.wifi.powersave = true;
  };
}
