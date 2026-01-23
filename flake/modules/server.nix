{ config, pkgs, lib, ... }: {
  boot.kernelParams = [ "preempt=voluntary" ];
  boot.kernel.sysctl = {
    # ipv6 privacy
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 0;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 0;
  };
  boot.kernel.sysfs = {
    # enable net card RPS & XPS
    class.net.end0.queues."rx-0".rps_cpus = "f";
    class.net.end0.queues."tx-0".rps_cpus = "f";
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
  environment.systemPackages = with pkgs; [ ethtool iproute2 ];
  networking.networkmanager.dispatcherScripts = [{
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
            bandwidth 370mbit \
            besteffort \
            wash \
            nat 
          $LOGGER -t gaming-sqm "Applied Wi-Fi (Safe) CAKE policy to $IFACE"
          ;;

        enp*|eth*|en*)
          # 以太网优化
          $ETHTOOL -K "$IFACE" gro off gso off tso off lro off || true
          
          $TC qdisc del dev "$IFACE" root 2>/dev/null || true
          $TC qdisc add dev "$IFACE" root cake \
            bandwidth 500mbit \
            diffserv4 \
            wash \
            nat \
            ack-filter
          $LOGGER -t gaming-sqm "Applied Ethernet (Aggressive) CAKE policy to $IFACE"
          ;;
      esac
    '';
  }];
}
