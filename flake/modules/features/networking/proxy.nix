{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ ../secrets/secrets.nix ];
  options.modules.proxy = {
    enable = lib.mkEnableOption "Enable customized proxy stack (Sing-box + Dae)";

    adguardhome.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable AdGuardHome as the DNS resolver backend.";
    };

    dnscrypt-proxy.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable dnscrypt-proxy as the DNS resolver backend.";
    };

    singbox.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sing-box as the proxy backend.";
    };
    singbox.dns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sing-box dns-in inbound (127.0.0.1:53).";
    };
    singbox.tun = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sing-box tun-in inbound.";
    };
    singbox.endpoints = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sops secret for sing-box endpoints.";
    };
    singbox.outbounds = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sops secret for sing-box outbounds.";
    };

    dae.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable dae as the Tproxy backend.";
    };
    dae.interfaces.wan = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "WAN interface for dae.";
    };
    dae.interfaces.lan = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "LAN interface for dae.";
    };
  };

  config =
    with lib;
    mkIf config.modules.proxy.enable {
      # 当开启透明代理 (TUN/TProxy) 时，必须优化内核与防火墙以支持非对称路由（如游戏 UDP）
      boot.kernel.sysctl = mkIf (config.modules.proxy.dae.enable || config.modules.proxy.singbox.tun) {
        "net.ipv4.conf.all.rp_filter" = 2;
        "net.ipv4.conf.default.rp_filter" = 2;
      };

      # dns-in 启用时：unbound 让出 53，sing-box dns-in 接管系统 DNS 入口
      services.unbound.settings.server.port = mkIf config.modules.proxy.singbox.dns 5353;

      # ----------------------------------------------------------------------------
      # start order
      # 1. 配置 Sing-box 的启动顺序：如果在该机器上启用了 AdGuardHome，则等待其启动

      # 2. 配置 Dae 的启动顺序：等待 Sing-box 和 AdGuardHome（如果它们存在）
      systemd.services.dae = mkIf config.modules.proxy.dae.enable {
        after = [
          "network-online.target"
        ]
        ++ (lib.optional config.modules.proxy.singbox.enable "sing-box.service")
        ++ (lib.optional config.services.unbound.enable "unbound.service")
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.dnscrypt-proxy.enable "dnscrypt-proxy.service");

        wants = [
          "network-online.target"
        ]
        ++ (lib.optional config.modules.proxy.singbox.enable "sing-box.service")
        ++ (lib.optional config.services.unbound.enable "unbound.service")
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.dnscrypt-proxy.enable "dnscrypt-proxy.service");
      };
      # start order
      # ----------------------------------------------------------------------------
      sops = {
        secrets = {
          doh_stamp = { };
          zerotrust = { };
          sing-box-endpoints = mkIf config.modules.proxy.singbox.endpoints { };
          sing-box-outbounds = mkIf config.modules.proxy.singbox.outbounds { };
          oracle_ip = { };
          oracle_domain = { };
        };
        templates = {
          "dnscrypt-proxy.toml" = lib.mkIf config.modules.proxy.dnscrypt-proxy.enable {
            mode = "0444";
            content = ''
              listen_addresses = ['[::]:53']
              block_ipv6 = true
              cache = true
              cache_size = 4096
              dnscrypt_servers = true
              doh_servers = true
              ipv4_servers = true
              ipv6_servers = false
              lb_strategy = "p2"
              netprobe_timeout = 300
              odoh_servers = true
              require_dnssec = false
              require_nofilter = false
              require_nolog = false
              server_names = ["cloudflare", "cloudflare-security", "mullvad-adblock-doh", "mullvad-all-doh", "mullvad-base-doh", "mullvad-doh", "mullvad-extend-doh", "nextdns", "nextdns-ultralow", "controld-block-malware", "controld-block-malware-ad", "controld-block-malware-ad-social", "controld-uncensored", "controld-unfiltered", "dns0", "dns0-unfiltered", "adguard-dns-doh", "adguard-dns-unfiltered-doh", "quad9-dnscrypt-ip4-filter-ecs-pri", "quad9-dnscrypt-ip4-filter-pri", "quad9-dnscrypt-ip4-nofilter-ecs-pri", "quad9-dnscrypt-ip4-nofilter-pri", "quad9-doh-ip4-port443-filter-ecs-pri", "quad9-doh-ip4-port443-filter-pri", "quad9-doh-ip4-port443-nofilter-ecs-pri", "quad9-doh-ip4-port443-nofilter-pri", "quad9-doh-ip4-port5053-filter-ecs-pri", "quad9-doh-ip4-port5053-filter-pri", "quad9-doh-ip4-port5053-nofilter-ecs-pri", "quad9-doh-ip4-port5053-nofilter-pri", "rethinkdns-doh", "flymc-doh-8443", "flymc-doh", "zerotrust"]

              [blocked_names]
              blocked_names_file = "${inputs.dnscrypt-blocklist}"

              [monitoring_ui]
              enabled = true
              listen_address = "0.0.0.0:9007"
              prometheus_enabled = true
              username = ""
              password = ""

              [sources]
              [sources.public-resolvers]
              cache_file = "public-resolvers.md"
              minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
              refresh_delay = 72
              urls = ["https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md", "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"]

              [static]
              [static.flymc-doh]
              stamp = "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyAAxkbnMuZmx5bWMuY2MKL2Rucy1xdWVyeQ"
              [static.flymc-doh-8443]
              stamp = "sdns://AgQAAAAAAAAADjQzLjE1NC4xNTQuMTYyABFkbnMuZmx5bWMuY2M6ODQ0MwovZG5zLXF1ZXJ5"
              [static.zerotrust]
              stamp = "${config.sops.placeholder.doh_stamp}"
            '';
          };
          "config.json" = lib.mkIf config.modules.proxy.singbox.enable {
            owner = "sing-box"; # 确保 sing-box 进程有权读取
            restartUnits = [ "sing-box.service" ]; # 模板变化时重启服务
            content = ''
              {
                "log": {
                  "level": "warn",
                  "timestamp": true
                },
                "dns": {
                  "servers": [
                    {
                      "type": "fakeip",
                      "tag": "fakeip",
                      "inet4_range": "198.18.0.0/15",
                      "inet6_range": "64:ff9b:1::/48"
                    },
                    // dns-mdns requires sing-box >= 1.14.0
                    // {"type": "mdns", "tag": "dns-mdns"},
                    // dns-dhcp removed: never referenced in DNS rules, causes startup
                    // "fetch DNS servers: context deadline exceeded" before NM is ready
                    {
                      "type": "local",
                      "tag": "dns-system"
                    },
                    {
                      "type": "udp",
                      "tag": "dns-unbound",
                      "server": "127.0.0.1",
                      "server_port": ${if config.modules.proxy.singbox.dns then "5353" else "53"}
                    },
                    {
                      "type": "h3",
                      "tag": "dns-alidns",
                      "server": "223.6.6.6",
                      "detour": "cn",
                      "tls": {
                        "enabled": true,
                        "record_fragment": true,
                        "server_name": "dns.alidns.com",
                        "curve_preferences": ["X25519MLKEM768", "X25519"]
                      }
                    },
                    {
                      "type": "h3",
                      "tag": "dns-flymc",
                      "server": "43.154.154.162",
                      "detour": "cn",
                      "tls": {
                        "enabled": true,
                        "record_fragment": true,
                        "server_name": "dns.flymc.cc",
                        "curve_preferences": ["X25519MLKEM768", "X25519"]
                      }
                    },
                    {
                      "type": "h3",
                      "tag": "dns-cloudflare",
                      "server": "172.64.36.2",
                      "tls": {
                        "enabled": true,
                        "record_fragment": true,
                        "server_name": "${config.sops.placeholder.zerotrust}",
                        "curve_preferences": ["X25519MLKEM768", "X25519"]
                      }
                    },
                    {
                      "type": "h3",
                      "tag": "dns-quad9",
                      "server": "149.112.112.11",
                      "detour": "oversea",
                      "tls": {
                        "enabled": true,
                        "record_fragment": true,
                        "server_name": "dns11.quad9.net",
                        "curve_preferences": ["X25519MLKEM768", "X25519"]
                      }
                    }
                  ],
                  "rules": [
                    {
                      "rule_set": "adblock-dns",
                      "action": "reject"
                    },
                    // dns-mdns requires sing-box >= 1.14.0
                    // {"domain_suffix": [".local"], "server": "dns-mdns"},
                    {
                      "type": "logical",
                      "mode": "or",
                      "rules": [
                        {
                          "domain_keyword": [
                            "msftconnecttest.com",
                            "msftncsi.com",
                            "linksys.com",
                            "linksyssmartwifi.com",
                            "hydroakri.cc"
                          ]
                        },
                        {
                          "domain_suffix": [
                            "wlan",
                            "intranet",
                            "private",
                            "domain",
                            "home",
                            "host",
                            "corp"
                          ]
                        },
                        {
                          "rule_set": [
                            "geosite-private"
                          ]
                        }
                      ],
                      "server": "dns-system"
                    },
                    // CN 域名解析器选择：
                    // - 桌面 (unbound 可用)：改为 dns-unbound。纯递归，从真实 IP 查 CN 权威 DNS
                    //   → GeoDNS 精准返回最近 CDN 节点，DNSSEC 验证，无商业日志。CN 域名本身
                    //   无隐私顾虑（访问服务本身已暴露 IP），权威 DNS 不受 GFW 污染。
                    // - 手机 (unbound 不可用)：保持 dns-alidns。H3 加密，detour:cn 直连阿里
                    //   DNS PoP，GeoDNS 覆盖好；ISP DNS 在 TUN 模式下行为不可预测，可能环路。
                    {
                      "rule_set": [
                        "geosite-tld-cn",
                        "geosite-geolocation-cn",
                        "geosite-cn"
                      ],
                      "server": "dns-alidns"
                    },
                    {
                      "query_type": [
                        "A",
                        "AAAA"
                      ],
                      "server": "fakeip"
                    }
                  ],
                  // final：处理未被任何规则匹配的查询（实际上只剩非 A/AAAA 记录，如 MX/TXT/HTTPS，
                  // 因为 A/AAAA 已被 fakeip 规则全部捕获）。用 dns-quad9 (detour:oversea)，
                  // 加密防污染，通过隧道发出，GFW 无法干扰。
                  "final": "dns-quad9",
                  "strategy": "prefer_ipv4",
                  "cache_capacity": 4096,
                  // "optimistic": true,  // sing-box >= 1.14.0: serve stale cache while refreshing in background
                  // "timeout": "10s",    // sing-box >= 1.14.0: default per-query timeout
                  "reverse_mapping": false
                },
                "endpoints": ${
                  if config.modules.proxy.singbox.endpoints then config.sops.placeholder.sing-box-endpoints else "[]"
                },
                "inbounds": [
                  ${lib.optionalString config.modules.proxy.singbox.dns ''
                    {
                      "type": "direct",
                      "tag": "dns-in",
                      "listen": "127.0.0.1",
                      "listen_port": 53
                    },
                  ''}
                  ${lib.optionalString config.modules.proxy.singbox.tun ''
                    {
                      "type": "tun",
                      "tag": "tun-in",
                      "interface_name": "tun0",
                      "mtu": 1280,
                      "address": [
                        "172.19.0.1/30",
                        "fdfe:dcba:9876::1/126"
                      ],
                      "auto_route": true,
                      "auto_redirect": true,
                      "strict_route": true,
                      "exclude_mptcp": true,
                      "stack": "mixed",
                      "exclude_uid_range": ["${toString config.users.users.unbound.uid}:${toString config.users.users.unbound.uid}"]
                    },
                  ''}
                  {
                    "type": "mixed",
                    "tag": "mixed-in",
                    "listen": "127.0.0.1",
                    "listen_port": 1080
                  }
                ],
                "outbounds": [
                  {
                    "type": "direct",
                    "tag": "direct",
                    "udp_fragment": true,
                    "tcp_multi_path": true,
                    // direct.domain_resolver：仅在 SOCKS/HTTP 代理模式下 direct outbound 收到
                    // 域名目标时触发（TUN 模式下 CN 域名已由 dns.rules 解析为真实 IP，经
                    // geoip-cn 匹配后以 IP 直连，不触发此字段）。用 dns-cloudflare (https,无
                    // detour)：CloudFlare DoH over TCP，在国内直连可用，防 GFW 污染，比 unbound
                    // 更安全（unbound 在此场景有递归泄露风险）。
                    "domain_resolver": {
                      "server": "dns-cloudflare",
                      "strategy": "prefer_ipv4"
                    }
                  },
                  {
                    "type": "selector",
                    "tag": "cn",
                    "outbounds": [
                      "direct"
                      ${lib.optionalString config.modules.proxy.singbox.outbounds '',"isp","proxy","manual"''}
                    ]
                  },
                  {
                    "type": "selector",
                    "tag": "oversea",
                    "outbounds": [
                      "direct"
                      ${lib.optionalString config.modules.proxy.singbox.outbounds '',"isp","proxy","manual"''}
                    ]
                  },
                  {
                    "type": "selector",
                    "tag": "ai-media-social",
                    "outbounds": [
                      "direct"
                      ${lib.optionalString config.modules.proxy.singbox.outbounds '',"isp","manual"''}
                    ]
                  },
                  {
                    "type": "selector",
                    "tag": "webrtc-bt-proxy",
                    "outbounds": [
                      "direct"
                      ${lib.optionalString config.modules.proxy.singbox.outbounds '',"isp","proxy","manual"''}
                    ]
                  },
                  ${lib.optionalString config.modules.proxy.singbox.endpoints ''
                    {
                      "type": "selector",
                      "tag": "tailscale-out",
                      "outbounds": [
                        "direct"
                        ${lib.optionalString config.modules.proxy.singbox.outbounds '',"isp","proxy","manual"''}
                      ]
                    }
                  ''}
                  ${
                    if config.modules.proxy.singbox.outbounds then config.sops.placeholder.sing-box-outbounds else ""
                  }
                ],
                "route": {
                  "rules": [
                    {
                      "inbound": [
                        ${lib.optionalString config.modules.proxy.singbox.tun ''"tun-in",''}
                        "mixed-in"
                      ],
                      "action": "sniff",
                      "timeout": "300ms"
                    },
                    {
                      "type": "logical",
                      "mode": "or",
                      "rules": [
                        ${lib.optionalString config.modules.proxy.singbox.dns ''
                          {
                            "inbound": "dns-in"
                          },
                        ''}
                        {
                          "port": 53
                        },
                        {
                          "protocol": "dns"
                        }
                      ],
                      "action": "hijack-dns"
                    },
                    {
                      "rule_set": "adblock-dns",
                      "action": "reject",
                      "method": "drop"
                    },
                    ${lib.optionalString config.modules.proxy.singbox.endpoints ''
                      {
                        "ip_cidr": [
                          "100.64.0.0/10",
                          "fd7a:115c:a1e0::/48"
                        ],
                        "outbound": "tailscale-in"
                      },
                      {
                        "type": "logical",
                        "mode": "or",
                        "rules": [
                          { "domain": ["${config.sops.placeholder.oracle_domain}"] },
                          { "rule_set": ["geosite-tailscale"] },
                          { "ip_cidr": ["${config.sops.placeholder.oracle_ip}/32"] }
                        ],
                        "outbound": "tailscale-out"
                      },
                    ''}
                    {
                      "rule_set": [
                        "geoip-private",
                        "geosite-private"
                      ],
                      "action": "bypass" // Linux only option
                      // "outbound": "direct" // For general
                    },
                    {
                      "type": "logical",
                      "mode": "or",
                      "rules": [
                        {
                          "protocol": [
                            "bittorrent",
                            "stun"
                          ]
                        },
                        {
                          "rule_set": [
                            "geosite-category-pt",
                            "geosite-category-public-tracker"
                          ]
                        }
                      ],
                      "outbound": "webrtc-bt-proxy"
                    },
                    {
                      "type": "logical",
                      "mode": "or",
                      "rules": [
                        {
                          "domain_suffix": "tradingview.com"
                        },
                        {
                          "rule_set": [
                            "geosite-google",
                            "geosite-google-cn"
                          ]
                        }
                      ],
                      "outbound": "oversea"
                    },
                    {
                      "rule_set": [
                        "geosite-category-ai-chat-!cn",
                        "geosite-category-ai-!cn",
                        "geosite-category-ai-chat-!cn@!cn",
                        "geosite-category-media",
                        "geosite-category-entertainment",
                        "geosite-category-entertainment@!cn",
                        "geosite-category-emby",
                        "geosite-category-social-media-!cn",
                        "geosite-category-social-media-!cn@cn"
                      ],
                      "outbound": "ai-media-social"
                    },
                    {
                      "rule_set": [
                        "geosite-apple@cn",
                        "geosite-category-games-cn",
                        "geosite-category-game-accelerator-cn",
                        "geosite-category-game-platforms-download",
                        "geosite-category-bank-cn",
                        "geosite-category-finance",
                        "geosite-category-securities-cn",
                        "geosite-category-cryptocurrency"
                      ],
                      "outbound": "direct"
                    },
                    {
                      "rule_set": [
                        "geosite-gfw",
                        "geosite-geolocation-!cn"
                      ],
                      "outbound": "oversea"
                    },
                    {
                      "rule_set": ["geoip-cn"],
                      "outbound": "cn"
                    },
                    {
                      "type": "logical",
                      "mode": "and",
                      "rules": [
                        {
                          "domain_regex": ".*"
                        },
                        {
                          "rule_set": [
                            "geosite-tld-cn",
                            "geosite-geolocation-cn",
                            "geosite-cn"
                          ],
                          "invert": true
                        }
                      ],
                      "outbound": "oversea"
                    },
                    {
                      "rule_set": [
                        "geosite-tld-cn",
                        "geosite-geolocation-cn",
                        "geosite-cn"
                      ],
                      "outbound": "cn"
                    }
                  ],
                  "rule_set": [
                    {
                      "type": "remote",
                      "tag": "adblock-dns",
                      "url": "https://cdn.jsdelivr.net/gh/hydroakri/dnscrypt-proxy-blocklist@release/blocklist.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geoip-private",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/private.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geoip-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-private",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/private.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-google-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/google-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-google",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/google.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-apple@cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/apple@cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-games-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-games-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-game-accelerator-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-game-accelerator-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-game-platforms-download",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-game-platforms-download.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-pt",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-pt.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-public-tracker",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-public-tracker.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-bank-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-bank-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-finance",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-finance.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-securities-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-securities-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-gfw",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/gfw.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-geolocation-!cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-!cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-tld-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/tld-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-geolocation-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-cryptocurrency",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-cryptocurrency.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-ai-chat-!cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-ai-chat-!cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-ai-!cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-ai-!cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-ai-chat-!cn@!cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-ai-chat-!cn@!cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-media",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-media.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-entertainment",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-entertainment.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-entertainment@!cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-entertainment@!cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-emby",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-emby.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-social-media-!cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-social-media-!cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-category-social-media-!cn@cn",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-social-media-!cn@cn.srs",
                      "update_interval": "24h0m0s"
                    },
                    {
                      "type": "remote",
                      "tag": "geosite-tailscale",
                      "url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/tailscale.srs",
                      "update_interval": "24h0m0s"
                    }
                  ],
                  "final": "oversea",
                  "auto_detect_interface": true,
                  // default_domain_resolver：代理 outbound 解析服务器域名时的默认 resolver
                  // （代理节点若用 IP 则不触发）。用 dns-quad9 (detour:oversea)：查询走隧道，
                  // GFW 无法污染代理服务器的域名解析。无循环风险（代理节点均为 IPv4 直连）。
                  "default_domain_resolver": {
                    "server": "dns-quad9",
                    "strategy": "prefer_ipv4"
                  }
                },
                "experimental": {
                  "cache_file": {
                    "enabled": true,
                    "path": "cache.db",
                    "store_fakeip": true,
                    "store_rdrc": true,  // deprecated in sing-box 1.14.0
                    // "store_dns": true  // sing-box >= 1.14.0: persist DNS cache across restarts
                  },
                  "clash_api": {
                    "external_controller": "127.0.0.1:9090",
                    "external_ui": "ui",
                    "secret": ""
                  }
                }
              } 
            '';
          };
        };
      };
      networking.networkmanager.insertNameservers = mkIf (
        config.modules.proxy.adguardhome.enable
        || config.modules.proxy.dnscrypt-proxy.enable
        || config.modules.proxy.singbox.dns
      ) [ "127.0.0.1" ];

      networking.firewall = lib.mkMerge [
        {
          checkReversePath = mkIf (config.modules.proxy.dae.enable || config.modules.proxy.singbox.tun) (
            lib.mkDefault false
          );
        }
        # AdGuardHome 的端口规则
        (mkIf config.modules.proxy.adguardhome.enable {
          allowedTCPPorts = [
            53
            80
            443
            3000
          ];
          allowedUDPPorts = [
            53
            1080
            67
            68
            547
            546
          ];
        })

        # dnscrypt-proxy 的端口规则
        (mkIf config.modules.proxy.dnscrypt-proxy.enable {
          allowedTCPPorts = [ 9007 ];
          allowedUDPPorts = [ 53 ];
        })

        # Sing-box 的端口规则
        (mkIf config.modules.proxy.singbox.enable {
          allowedTCPPorts = [
            1080
            9090
          ];
          allowedUDPPorts = [ 1080 ];
        })
      ];

      services.adguardhome.enable = mkIf config.modules.proxy.adguardhome.enable true;
      systemd.services.adguardhome = mkIf config.modules.proxy.adguardhome.enable {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          AmbientCapabilities = [
            "CAP_NET_BIND_SERVICE"
            "CAP_NET_RAW"
          ];
          CapabilityBoundingSet = [
            "CAP_NET_BIND_SERVICE"
            "CAP_NET_RAW"
          ];
        };
      };

      services.dnscrypt-proxy = mkIf config.modules.proxy.dnscrypt-proxy.enable {
        enable = true;
        package = pkgs.pkgsMusl.dnscrypt-proxy;
        configFile = config.sops.templates."dnscrypt-proxy.toml".path;
      };
      systemd.services.dnscrypt-proxy = mkIf config.modules.proxy.dnscrypt-proxy.enable {
        restartTriggers = [ config.sops.templates."dnscrypt-proxy.toml".path ];
      };

      services.sing-box = mkIf config.modules.proxy.singbox.enable {
        enable = true;
        package = pkgs.pkgsMusl.sing-box;
      };
      systemd.services.sing-box = mkIf config.modules.proxy.singbox.enable {
        after = [
          "network-online.target"
        ]
        ++ (lib.optional config.services.unbound.enable "unbound.service")
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.dnscrypt-proxy.enable "dnscrypt-proxy.service");

        wants = [
          "network-online.target"
        ]
        ++ (lib.optional config.services.unbound.enable "unbound.service")
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.dnscrypt-proxy.enable "dnscrypt-proxy.service");

        restartTriggers = [ config.sops.templates."config.json".path ];

        serviceConfig.ExecStart = (
          lib.mkForce [
            ""
            "${pkgs.pkgsMusl.sing-box}/bin/sing-box run -c ${config.sops.templates."config.json".path}"
          ]
        );
      };

      services.dae = mkIf config.modules.proxy.dae.enable {
        enable = true;
        # configFile = "/etc/dae/config.dae";
        assetsPath = toString (
          pkgs.symlinkJoin {
            name = "dae-assets";
            paths = [ "${inputs.geodb}" ];
          }
        );
        config = ''
          global {
            dial_mode: domain
            lan_interface: ${config.modules.proxy.dae.interfaces.lan}
            wan_interface: ${config.modules.proxy.dae.interfaces.wan}
            log_level: info

            # health check
            tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1,2606:4700:4700::1111'
            tcp_check_http_method: HEAD
            udp_check_dns: 'dns9.quad9.net:53,9.9.9.9,2620:fe::fe'
            check_interval: 30s
            check_tolerance: 50ms

            # safety & security
            mptcp: false
            so_mark_from_dae: 0
            allow_insecure: false
            tls_implementation: utls
            utls_imitate: chrome_auto
            disable_waiting_network: false

            # performance
            pprof_port: 0
            sniffing_timeout: 100ms
            tproxy_port_protect: true
            auto_config_kernel_parameter: true
          }

          node {
            'socks5://localhost:1080'
          }

          dns {
            ipversion_prefer: 4
            upstream {
              alih3: 'h3://dns.alidns.com:443/dns-query'
              flymc: 'quic://dns.flymc.cc:853'
              localdns: 'udp://127.0.0.1:53'
            }
            routing {
              request {
                qname(geosite:apple@cn, geosite:category-games-cn, geosite:category-game-accelerator-cn, geosite:category-game-platforms-download, geosite:category-bank-cn, geosite:category-finance, geosite:category-securities-cn, geosite:tld-cn, geosite:geolocation-cn, geosite:cn, geosite:china-list) -> alih3
                fallback: localdns
              }
              response {
                !qname(geosite:tld-cn, geosite:geolocation-cn, geosite:cn) && qtype(aaaa) -> reject
                fallback: accept
              }
            }
          }

          group {
              proxy {
                  policy: min_moving_avg
              }
          }

          routing {
            pname(NetworkManager, chronyd, dnscrypt-proxy, AdGuardHome, nekoray, nekobox_core, sing-box, verge-mihomo, clash-verge, clash-verge-service) -> must_direct
            dip(224.0.0.0/3, 'ff00::/8', geoip:private) -> must_direct
            domain(geosite:private) -> must_direct
            domain(geosite:category-ads-all) -> block

            # force abroad ipv6 proxy
            ipversion(6) -> proxy

            # bypass BT / PT (route through sing-box webrtc-bt-proxy selector)
            dscp(0x4) -> direct
            domain(keyword: tracker, announce, torrent) -> proxy
            domain(geosite:category-pt, geosite:category-public-tracker) -> proxy

            # set specific situation
            domain(geosite:google-cn, geosite:google, tradingview.com) -> proxy
            domain(geosite:apple@cn, geosite:category-games-cn, geosite:category-game-accelerator-cn, geosite:category-game-platforms-download, geosite:category-bank-cn, geosite:category-finance, geosite:category-securities-cn, geosite:category-cryptocurrency) -> direct

            # set general abroad situation
            domain(geosite:gfw, geosite:geolocation-!cn) -> proxy
            !domain(geosite:tld-cn, geosite:geolocation-cn, geosite:cn) -> proxy

            # set general domestic situation
            domain(geosite:tld-cn, geosite:geolocation-cn, geosite:cn, geosite:china-list) -> direct
            dip(geoip:cn) -> direct

            fallback: proxy
          }
        '';
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
