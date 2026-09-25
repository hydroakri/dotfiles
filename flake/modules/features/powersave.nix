{
  config,
  lib,
  pkgs,
  ...
}:
let
  sndHdaBattery = pkgs.writeShellScript "snd-hda-battery" ''
    echo 1 > /sys/module/snd_hda_intel/parameters/power_save
  '';

  sndHdaAc = pkgs.writeShellScript "snd-hda-ac" ''
    echo 0 > /sys/module/snd_hda_intel/parameters/power_save
  '';

  aspmBattery = pkgs.writeShellScript "aspm-battery" ''
    echo powersupersave > /sys/module/pcie_aspm/parameters/policy
  '';

  # Pop!_OS 原版 lib/systemd/system-sleep/pop-default-settings_bluetooth-suspend；
  # 部分蓝牙网卡挂起时不清空状态会导致唤醒后连不上，挂起前强制 block、唤醒后按挂起
  # 前的实际状态恢复（如果本来就是 block 的，恢复后还是 block，不会意外打开）
  bluetoothSuspendWorkaround = pkgs.writeShellScript "bluetooth-suspend-workaround" ''
    set -e
    BT_BLOCK_PATH=/run/bluetooth.blocked
    BT_STATES_PATH=/var/lib/systemd/rfkill/
    BT_TMP_PATH=/tmp/

    case "$2" in
      suspend | hybrid-sleep)
        case "$1" in
          pre)
            if ${pkgs.util-linux}/bin/rfkill -o ID,TYPE,SOFT | grep -q -E 'bluetooth\s+unblocked'; then
              cp "$BT_STATES_PATH"*bluetooth "$BT_TMP_PATH"
              ${pkgs.util-linux}/bin/rfkill block bluetooth
            else
              > "$BT_BLOCK_PATH"
            fi
            ;;
          post)
            cp -f "$BT_TMP_PATH"*bluetooth "$BT_STATES_PATH" 2>/dev/null
            [ ! -f "$BT_BLOCK_PATH" ] && sleep 1 && ${pkgs.util-linux}/bin/rfkill unblock bluetooth
            rm -f "$BT_BLOCK_PATH" 2>/dev/null
            rm -f "$BT_TMP_PATH"*bluetooth 2>/dev/null
            ;;
        esac
        ;;
    esac
  '';

  # Pop!_OS 原版 usr/lib/iw-set-regdomain；按系统时区反查国家码，`iw reg set` 对应
  # 监管域（信道可用性/最大发射功率按国家而定）。原脚本假设 /etc/localtime 指向
  # /usr/share/zoneinfo/<Zone>，NixOS 上实际指向 tzdata 的 nix store 路径，这里改成
  # 通配去掉 "share/zoneinfo/" 前缀，不依赖具体 store hash
  iwSetRegdomain = pkgs.writeShellScript "iw-set-regdomain" ''
    set -e
    LOGGER="${pkgs.util-linux}/bin/logger -t iw-set-regdomain"

    getcountry() {
      while read -r c a z r; do
        if [ "$z" = "$ZONE" ]; then
          echo "$c"
          break
        fi
      done < "${pkgs.tzdata}/share/zoneinfo/zone.tab"
    }

    if [ -f /etc/localtime ]; then
      ZONE=$(${pkgs.coreutils}/bin/readlink -f /etc/localtime)
      ZONE=''${ZONE##*/share/zoneinfo/}
    else
      $LOGGER -s "Timezone information not found. Unable to set wireless regulatory domain."
      exit 1
    fi

    if [ -z "$ZONE" ] || [ "$ZONE" = "/etc/localtime" ]; then
      $LOGGER -s "Could not determine timezone. Unable to set wireless regulatory domain."
      exit 1
    fi

    COUNTRY=$(getcountry)

    if [ -z "$COUNTRY" ]; then
      case "$ZONE" in
        UTC | UCT | Universal | Zulu | GMT | Etc/UTC | Etc/UCT | Etc/Universal | Etc/Zulu | Etc/GMT)
          $LOGGER "Timezone is $ZONE, with no associated country. Not setting wireless regulatory domain."
          exit 0
          ;;
      esac
      $LOGGER -s "Could not determine country for $ZONE. Unable to set wireless regulatory domain."
      exit 1
    fi

    $LOGGER "Setting regulatory domain to $COUNTRY based on timezone ($ZONE)."
    ${pkgs.iw}/bin/iw reg set "$COUNTRY"
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

  config = lib.mkIf config.modules.powersave.enable {
    boot.kernelModules = [ "rtc_cmos" ];
    boot.extraModprobeConfig = ''
      # Enable U-APSD for iwlwifi (deeper WiFi sleep)
      options iwlwifi uapsd_disable=0
    '';
    boot.kernelParams = [
      "nowatchdog"
      "nmi_watchdog=0"
      "amd_pstate=active"
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
      "kernel.nmi_watchdog" = lib.mkOverride 950 0;
      # 硬件 lockup watchdog 总开关；nmi_watchdog 只关 NMI 子类型，这个更彻底
      "kernel.watchdog" = lib.mkOverride 950 0;
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

      # 新网卡插入时按时区设监管域
      SUBSYSTEM=="ieee80211", ACTION=="add", RUN+="${iwSetRegdomain}"
    '';
    # services.auto-cpufreq.enable = true;
    services.power-profiles-daemon.enable = lib.mkDefault true;
    services.irqbalance.enable = lib.mkDefault true;

    # 挂起前 block 蓝牙、唤醒后按原状态恢复
    environment.etc."systemd/system-sleep/bluetooth-suspend-workaround" = {
      source = bluetoothSuspendWorkaround;
      mode = "0755";
    };

    # 按时区自动设 WiFi 监管域：开机(udev coldplug 补放 add 事件)、时区变化
    # (.path 单元)、插新网卡(udev add 事件)三种时机都会触发
    systemd.services.iw-set-regdomain = {
      description = "Set wireless regulatory domain based on timezone";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${iwSetRegdomain}";
      };
    };
    systemd.paths.iw-set-regdomain = {
      description = "Watch timezone changes to re-set wireless regulatory domain";
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = "/etc/localtime";
    };
    networking.interfaces = lib.genAttrs config.modules.powersave.wakeOnLan.interfaces (_name: {
      wakeOnLan.enable = lib.mkDefault false;
    });
    networking.networkmanager.wifi.powersave = lib.mkDefault true;
  };
}
