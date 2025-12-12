{ config, lib, pkgs, inputs, ... }:
with lib; {
  imports = [ ./secrets/secrets.nix ];
  options.modules.proxy = {
    enable = mkEnableOption "Enable customized proxy stack (Sing-box + Dae)";

    enableDnsCryptProxy = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dnscrypt-proxy as the DNS resolver backend.";
    };
    enableDae = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dae as the Tproxy backend.";
    };
    enableSingbox = mkOption {
      type = types.bool;
      default = false;
      description = "Enable sing-box as the proxy backend.";
    };
  };
  config = mkIf config.modules.proxy.enable {
    services.sing-box = mkIf config.modules.proxy.enableSingbox {
      enable = true;
      package = pkgs.sing-box;
      settings = {
        log = {
          level = "info";
          timestamp = true;
        };
        dns = {
          servers = [{
            tag = "local-dns";
            address = "local";
            detour = "direct"; # DNS 流量直连发出
          }];
          rules = [{
            outbound = "any";
            server = "local-dns"; # 所有 DNS 请求都强制走这个 local-dns
          }];
        };
        experimental = {
          cache_file = {
            enabled = true;
            path = "cache.db"; # 默认在 /var/lib/sing-box/cache.db
            store_fakeip = false;
          };
          clash_api = {
            external_controller = "0.0.0.0:9090"; # 面板连接地址
            external_ui = "ui"; # 如果你不需要本地托管面板界面，可删除此行
            secret = ""; # 如果需要鉴权，在这里填写 API 密钥
          };
        };
        inbounds = [{
          type = "mixed";
          tag = "mixed-in";
          listen = "127.0.0.1"; # 仅监听本地，不暴露给局域网
          listen_port = 1080;
          set_system_proxy = false;
        }];
        route = {
          rules = [{
            protocol = "dns";
            outbound = "dns-out";
          }
          # { geosite = "cn"; outbound = "direct"; }
            ];
          auto_detect_interface = true;
        };
        outbounds = "OUTBOUNDS_PLACEHOLDER";
      };
    };
    systemd.services.sing-box.serviceConfig.ExecStart =
      mkIf config.modules.proxy.enableSingbox (lib.mkForce [
        ""
        "${pkgs.sing-box}/bin/sing-box run -c ${
          config.sops.templates."config.json".path
        }"
      ]);
    services.dae = mkIf config.modules.proxy.enableDae {
      enable = true;
      # configFile = "/etc/dae/config.dae";
      assetsPath = toString (pkgs.symlinkJoin {
        name = "dae-assets";
        paths = [ "${inputs.geodb}" ];
      });
      config = ''
        global {
          dial_mode: domain
          lan_interface: auto
          wan_interface: auto
          log_level: info
          auto_config_kernel_parameter: true
          tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1,2606:4700:4700::1111'
          tcp_check_http_method: HEAD
          check_interval: 30s
          check_tolerance: 50ms
        }

        node {
          'socks5://localhost:1080'
        }

        dns {
          upstream {
            alih3: 'h3://dns.alidns.com:443/dns-query'
            localdns: 'udp://127.0.0.1:53'
          }
          routing {
            request {
              qname(geosite:cn) -> alih3
              fallback: localdns
            }
          }
        }

        group {
            proxy {
                policy: min_moving_avg
            }
        }

        routing {
          pname(NetworkManager, dnscrypt-proxy, AdGuardHome, nekoray, nekobox_core, sing-box, verge-mihomo, clash-verge, clash-verge-service) -> must_direct
          dip(224.0.0.0/3, 'ff00::/8', geoip:private) -> must_direct

          dip(geoip:cn) -> direct 
          ip(geoip:cn) -> direct 
          domain(geosite:cn, geosite:geolocation-cn, geosite:china-list, geosite:apple-cn, geosite:google-cn) -> direct

          domain(geosite:gfw) -> proxy

          fallback: proxy
        }
      '';
    };
    services.dnscrypt-proxy = mkIf config.modules.proxy.enableDnsCryptProxy {
      enable = true;
      configFile = config.sops.templates."dnscrypt-proxy.toml".path;
      settings = {
        cache = true;
        cache_size = 4096;
        block_ipv6 = true;
        netprobe_timeout = 300;
        lb_strategy = "p2";
        blocked_names.blocked_names_file =
          pkgs.writeText "blocklist.txt" (builtins.readFile inputs.adlist);
        ipv4_servers = true;
        ipv6_servers = false;
        dnscrypt_servers = true;
        doh_servers = true;
        odoh_servers = true;
        require_dnssec = false;
        require_nolog = false;
        require_nofilter = false;
        server_names = [
          "cloudflare"
          "cloudflare-family"
          "cloudflare-security"
          "mullvad-adblock-doh"
          "mullvad-all-doh"
          "mullvad-base-doh"
          "mullvad-doh"
          "mullvad-extend-doh"
          "mullvad-family-doh"
          "nextdns"
          "nextdns-ultralow"
          "controld-block-malware"
          "controld-block-malware-ad"
          "controld-block-malware-ad-social"
          "controld-family-friendly"
          "controld-uncensored"
          "controld-unfiltered"
          "dns0"
          "dns0-kid"
          "dns0-unfiltered"
          "adguard-dns-doh"
          "adguard-dns-family-doh"
          "adguard-dns-unfiltered-doh"
          "quad9-dnscrypt-ip4-filter-ecs-pri"
          "quad9-dnscrypt-ip4-filter-pri"
          "quad9-dnscrypt-ip4-nofilter-ecs-pri"
          "quad9-dnscrypt-ip4-nofilter-pri"
          "quad9-doh-ip4-port443-filter-ecs-pri"
          "quad9-doh-ip4-port443-filter-pri"
          "quad9-doh-ip4-port443-nofilter-ecs-pri"
          "quad9-doh-ip4-port443-nofilter-pri"
          "quad9-doh-ip4-port5053-filter-ecs-pri"
          "quad9-doh-ip4-port5053-filter-pri"
          "quad9-doh-ip4-port5053-nofilter-ecs-pri"
          "quad9-doh-ip4-port5053-nofilter-pri"
          "rethinkdns-doh"
          "quad101"
          "flymc-doh-8443"
          "flymc-doh"
          "zerotrust"
        ];
        static.flymc-doh-8443.stamp =
          "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyABFkbnMuZmx5bWMuY2M6ODQ0MwovZG5zLXF1ZXJ5";
        static.flymc-doh.stamp =
          "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyAAxkbnMuZmx5bWMuY2MKL2Rucy1xdWVyeQ";
        static.zerotrust.stamp = config.modules.secrets.zeroTrust;
        sources.public-resolvers = {
          urls = [
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          ];
          cache_file = "public-resolvers.md";
          minisign_key =
            "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
          refresh_delay = 72;
        };
      };
    };

    # ProxyChains configuration
    environment.etc."proxychains.conf" = {
      text = ''
        strict_chain
        proxy_dns
        remote_dns_subnet 224
        tcp_read_time_out 15000
        tcp_connect_time_out 8000
        localnet 127.0.0.0/255.0.0.0
        localnet 10.0.0.0/255.0.0.0
        localnet 172.16.0.0/255.240.0.0
        localnet 192.168.0.0/255.255.0.0

        [ProxyList]
        socks5 127.0.0.1 1080
      '';
    };
  };
}
