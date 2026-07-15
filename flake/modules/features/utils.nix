{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.modules.utils = {
    enable = lib.mkEnableOption "enable some useful tools";

    enableGraphicTools = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    enableUptime = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    enableGrafana = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    enablePrometheus = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf config.modules.utils.enable {
    sops = {
      secrets = {
        grafana_secret_key = { };
      };
    };

    networking.firewall = lib.mkMerge [
      # grafana 的端口规则
      (lib.mkIf config.modules.utils.enableGrafana { allowedTCPPorts = [ 9006 ]; })
    ];

    environment.systemPackages = lib.mkIf config.modules.utils.enableGraphicTools ([
      ## GPU / display tools
      pkgs.nvtopPackages.full
      pkgs.virtualglLib
      pkgs.vulkan-tools
      pkgs.libva-utils
      pkgs.vdpauinfo
      pkgs.read-edid
      pkgs.clinfo
    ]);

    services.uptime-kuma = lib.mkIf config.modules.utils.enableUptime {
      enable = lib.mkDefault true;
      # 默认监听 3001 端口
    };

    services.prometheus = lib.mkIf config.modules.utils.enablePrometheus {
      enable = lib.mkDefault true;
      port = lib.mkDefault 9005;
      globalConfig.scrape_interval = lib.mkDefault "45s";

      exporters.node = {
        enable = lib.mkDefault true;
        port = lib.mkDefault 9100;
        enabledCollectors = [
          "systemd" # 核心：监控服务状态
          "tcpstat" # 核心：监控网络连接数
          "hwmon" # 核心：看温度
          "cpufreq" # 核心：看睿频
          "wifi" # 核心：看信号
          "cpu"
          "meminfo"
          "loadavg"
          "netdev"
          "filesystem"
        ];
      };
      scrapeConfigs = [
        {
          job_name = "desktop-metrics";
          static_configs = [
            {
              targets = [
                "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
              ];
            }
          ];
        }
        {
          job_name = "dnscrypt-proxy"; # 给你的 DNS 监控起个名字
          static_configs = [
            {
              targets = [ "127.0.0.1:9007" ]; # 直接指向 dnscrypt-proxy 暴露的端口
            }
          ];
        }
      ];
    };

    services.grafana = lib.mkIf config.modules.utils.enableGrafana {
      enable = lib.mkDefault true;
      settings = {
        security.secret_key = config.sops.placeholder.grafana_secret_key;
        server = {
          http_addr = lib.mkDefault "0.0.0.0";
          http_port = lib.mkDefault 9006;
          domain = lib.mkDefault "localhost";
          enforce_domain = lib.mkDefault false;
        };
      };
      provision = {
        enable = lib.mkDefault true;
        datasources.settings.datasources = [
          {
            name = "Prometheus-Desktop";
            type = "prometheus";
            url = "http://127.0.0.1:9005";
          }
        ];
        dashboards.settings.providers = [
          {
            name = "Desktop Dashboards";
            options.path = pkgs.fetchurl {
              url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
              sha256 = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
            };
          }
        ];
      };
    };
  };
}
