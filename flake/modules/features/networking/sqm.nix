{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.modules.networking.sqm = {
    enable = lib.mkEnableOption "SQM (Smart Queue Management) for gaming/networking";
    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp1s0";
      description = "WAN interface (connected to router/internet). Controls UPLOAD.";
    };
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp1s1";
      description = "LAN interface (connected to devices). Controls DOWNLOAD.";
    };
    uploadBandwidth = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "30mbit";
      description = "Upload bandwidth limit (90-95% of line rate). Leave null to run at interface line rate.";
    };
    downloadBandwidth = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "500mbit";
      description = "Download bandwidth limit (90-95% of line rate). Leave null to run at interface line rate.";
    };
    overhead = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Framing overhead (Set to 0 to disable).";
    };
  };

  config = lib.mkIf config.modules.networking.sqm.enable {
    environment.systemPackages = [
      pkgs.ethtool
      pkgs.iproute2
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

          # 构建参数字符串
          OVERHEAD_ARG=""
          [ ${toString config.modules.networking.sqm.overhead} -gt 0 ] && OVERHEAD_ARG="overhead ${toString config.modules.networking.sqm.overhead}"

          if [ "$IFACE" = "${config.modules.networking.sqm.wanInterface}" ]; then
              # 上传优化 (流向外网)
              if [[ "$IFACE" == wl* ]]; then
                  # Wi-Fi 特定优化
                  $ETHTOOL -K "$IFACE" gro off || true
              else
                  # 以太网优化
                  $ETHTOOL -K "$IFACE" gro off gso off tso off lro off || true
              fi
              $TC qdisc del dev "$IFACE" root 2>/dev/null || true
              CAKE_ARGS="diffserv4 triple-isolate wash ack-filter $OVERHEAD_ARG nat"
              ${lib.optionalString (
                config.modules.networking.sqm.uploadBandwidth != null
              ) "CAKE_ARGS=\"bandwidth ${config.modules.networking.sqm.uploadBandwidth} $CAKE_ARGS\""}
              $TC qdisc add dev "$IFACE" root cake $CAKE_ARGS
              $LOGGER -t gaming-sqm "Applied UPLOAD CAKE policy to $IFACE (via WAN)"
          fi

          if [ "$IFACE" = "${config.modules.networking.sqm.lanInterface}" ] && [ "${config.modules.networking.sqm.lanInterface}" != "${config.modules.networking.sqm.wanInterface}" ]; then
              # 下载优化 (流向内网)
              if [[ "$IFACE" == wl* ]]; then
                  # Wi-Fi 特定优化
                  $ETHTOOL -K "$IFACE" gro off || true
              else
                  # 以太网优化
                  $ETHTOOL -K "$IFACE" gro off gso off tso off lro off || true
              fi
              $TC qdisc del dev "$IFACE" root 2>/dev/null || true
              CAKE_ARGS="besteffort triple-isolate wash $OVERHEAD_ARG nat"
              ${lib.optionalString (
                config.modules.networking.sqm.downloadBandwidth != null
              ) "CAKE_ARGS=\"bandwidth ${config.modules.networking.sqm.downloadBandwidth} $CAKE_ARGS\""}
              $TC qdisc add dev "$IFACE" root cake $CAKE_ARGS
              $LOGGER -t gaming-sqm "Applied DOWNLOAD CAKE policy to $IFACE (via LAN)"
          fi
        '';
      }
    ];
  };
}
