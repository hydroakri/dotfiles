{ config, pkgs, lib, ... }: {
  boot.kernelParams = [ "preempt=voluntary" ];
  boot.kernel.sysctl = {
    # ipv6 privacy
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 0;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkForce 0;
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

  # Server monitoring: 服务稳定性、TCP 状态、长期资源占用
  services.prometheus = {
    enable = true;
    port = 9005; # 避开 sing-box 的 9090

    # 服务器环境：30s 间隔，平衡监控详细度和资源消耗
    globalConfig.scrape_interval = "30s";

    exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd" # 核心：监控服务状态
        "tcpstat" # 核心：监控网络连接数
        "cpu"
        "meminfo"
        "loadavg"
        "netdev"
        "diskstats"
        "filesystem"
      ];
    };
    scrapeConfigs = [{
      job_name = "server-metrics";
      static_configs = [{
        targets = [
          "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
        ];
      }];
    }];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        # 服务器环境：默认仅本地访问，确保安全
        # 如需开放到局域网，请改为 "0.0.0.0" 并配置防火墙
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "localhost";
        enforce_domain = false;
      };
    };
    provision = {
      enable = true;
      # 自动关联 Prometheus
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://127.0.0.1:9005";
      }];
      # 自动导入仪表盘 (Node Exporter Full)
      dashboards.settings.providers = [{
        name = "Server Dashboards";
        options.path = pkgs.fetchurl {
          url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
          sha256 = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
        };
      }];
    };
  };
}
