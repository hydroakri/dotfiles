{
  lib,
  ...
}:
{
  boot.kernelParams = [ "preempt=voluntary" ];
  networking.tempAddresses = lib.mkOverride 900 "disabled";
  boot.kernel.sysctl = {
    # networking.tempAddresses only drives *.default.use_tempaddr; .all isn't
    # covered by that option, so it still needs a direct assignment here.
    "net.ipv6.conf.all.use_tempaddr" = lib.mkOverride 900 0;

    # optimize bufferbloat
    # 下面 6 行目前被 performance.nix 的 mkOverride 950 压制，从未生效；暂无
    # 实测理由证明服务器场景需要更小缓冲区/backlog，保留但不提优先级
    "net.core.netdev_max_backlog" = lib.mkDefault 2000;
    "net.core.rmem_max" = lib.mkDefault 4194304;
    "net.core.wmem_max" = lib.mkDefault 4194304;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 4194304";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 87380 4194304";
    "net.ipv4.tcp_mem" = lib.mkDefault "4194304 4194304 4194304";
    "net.core.netdev_budget" = lib.mkDefault 600;
    "net.core.netdev_budget_usecs" = lib.mkDefault 8000;

    # 防半开连接/慢速握手耗尽资源（oci 对外暴露 nginx+多个服务；
    # rpi4-switch/rpi4-side-gateway 同样是 server.nix 角色，一并生效）
    "net.ipv4.tcp_ecn" = lib.mkDefault 0;
    "net.ipv4.tcp_syn_retries" = lib.mkDefault 4;
    "net.ipv4.tcp_synack_retries" = lib.mkDefault 3;
    "net.ipv4.tcp_orphan_retries" = lib.mkDefault 6;
    "net.ipv4.tcp_retries2" = lib.mkDefault 8;

    # 容纳大量/不稳定外部客户端连接（grapheneos-infra 服务器基础设施）；
    # mkOverride 900 高于 performance.nix/security.nix 的 950 基线覆盖；
    # ip_local_port_range 不覆盖——ANSSI 收窄攻击面优先于服务器出站端口容量
    "net.ipv4.tcp_fin_timeout" = lib.mkOverride 900 30;
    "net.ipv4.tcp_notsent_lowat" = lib.mkOverride 900 131072;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = lib.mkOverride 900 1800;
  };
  services.irqbalance.enable = lib.mkDefault true;
  services.fail2ban.enable = lib.mkDefault true;
  services.tuned.enable = lib.mkDefault true;
  environment.etc."tuned/active_profile".text = lib.mkDefault "throughput-performance";
  environment.etc."tuned/profile_mode".text = lib.mkDefault "manual";
}
