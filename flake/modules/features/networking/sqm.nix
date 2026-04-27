{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.networking.sqm;
in
{
  options.modules.networking.sqm = {
    enable = lib.mkEnableOption "SQM (Smart Queue Management) for gaming/networking";
    wifiBandwidth = lib.mkOption {
      type = lib.types.str;
      default = "370mbit";
      description = "Bandwidth limit for Wi-Fi interface in CAKE qdisc.";
    };
    ethernetBandwidth = lib.mkOption {
      type = lib.types.str;
      default = "500mbit";
      description = "Bandwidth limit for Ethernet interface in CAKE qdisc.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ethtool
      iproute2
    ];

    networking.networkmanager.dispatcherScripts = [
      {
        source = pkgs.writeShellScript "gaming-sqm" ''
          # 显式引用 Nix 路径，避免环境变量丢失
          ETHTOOL="${pkgs.ethtool}/bin/ethtool"
          TC="${pkgs.iproute2}/bin/tc"
          LOGGER="${pkgs.util-linux}/bin/logger"

          IFACE="$1"
          ACTION="$2"

          # 只在接口启动时运行
          [ "$ACTION" != "up" ] && exit 0

          # 简单的日志记录，方便用 journalctl -u NetworkManager 查看
          $LOGGER -t gaming-sqm "Configuring gaming network stack for $IFACE..."

          case "$IFACE" in
            wlo*|wl*)
              # Wi-Fi 优化
              # 关 GRO 可能导致瞬时重连，部分驱动不支持，加 true 忽略错误
              $ETHTOOL -K "$IFACE" gro off || true
              
              $TC qdisc del dev "$IFACE" root 2>/dev/null || true
              $TC qdisc add dev "$IFACE" root cake \
                bandwidth ${cfg.wifiBandwidth} \
                besteffort \
                wash
              $LOGGER -t gaming-sqm "Applied Wi-Fi (Safe) CAKE policy to $IFACE"
              ;;

            enp*|eth*|en*)
              # 以太网优化
              $ETHTOOL -K "$IFACE" gro off gso off tso off lro off || true
              
              $TC qdisc del dev "$IFACE" root 2>/dev/null || true
              $TC qdisc add dev "$IFACE" root cake \
                bandwidth ${cfg.ethernetBandwidth} \
                diffserv4 \
                triple-isolate \
                wash \
                ack-filter
              $LOGGER -t gaming-sqm "Applied Ethernet (Aggressive) CAKE policy to $IFACE"
              ;;
          esac
        '';
      }
    ];
  };
}
