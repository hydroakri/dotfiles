{ config, lib, pkgs, inputs, ... }:
with lib; {
  imports = [ ./secrets/secrets.nix ];
  options.modules.proxy = {
    enable = mkEnableOption "Enable customized proxy stack (Sing-box + Dae)";

    enableAdGuardHome = mkOption {
      type = types.bool;
      default = false;
      description = "Enable AdGuardHome as the DNS resolver backend.";
    };
    enableDnsCryptProxy = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dnscrypt-proxy as the DNS resolver backend.";
    };
    enableSingbox = mkOption {
      type = types.bool;
      default = false;
      description = "Enable sing-box as the proxy backend.";
    };
    enableDae = mkOption {
      type = types.bool;
      default = false;
      description = "Enable dae as the Tproxy backend.";
    };
  };

  config = mkIf config.modules.proxy.enable {
    # ----------------------------------------------------------------------------
    # start order
    # 1. 配置 Sing-box 的启动顺序：如果在该机器上启用了 AdGuardHome，则等待其启动

    # 2. 配置 Dae 的启动顺序：等待 Sing-box 和 AdGuardHome（如果它们存在）
    systemd.services.dae = mkIf config.modules.proxy.enableDae {
      after = [ "network-online.target" "systemd-networkd-wait-online.service" ]
        ++ (lib.optional config.modules.proxy.enableSingbox "sing-box.service")
        ++ (lib.optional config.modules.proxy.enableAdGuardHome
          "adguardhome.service")
        ++ (lib.optional config.modules.proxy.enableDnsCryptProxy
          "dnscrypt-proxy.service");

      wants = [ "network-online.target" ]
        ++ (lib.optional config.modules.proxy.enableSingbox "sing-box.service")
        ++ (lib.optional config.modules.proxy.enableAdGuardHome
          "adguardhome.service")
        ++ (lib.optional config.modules.proxy.enableDnsCryptProxy
          "dnscrypt-proxy.service");
    };
    # start order
    # ----------------------------------------------------------------------------
    sops = {
      secrets = {
        doh_stamp = { };
        zerotrust = { };
        sing-box-endpoints = { };
        sing-box-outbounds = { };
      };
      templates = {
        "dnscrypt-proxy.toml" = {
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
            blocked_names_file = "/var/lib/dnscrypt-proxy/blocklist.txt"

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
        "config.json" = {
          owner = "sing-box"; # 确保 sing-box 进程有权读取
          restartUnits = [ "sing-box.service" ]; # 模板变化时重启服务
          content = ''
            {
              "log": {
                "level": "error",
                "timestamp": true
              },
              "dns": {
                "servers": [
                  {
                    "type": "fakeip",
                    "tag": "fakeip",
                    "inet4_range": "198.18.0.0/16",
                    "inet6_range": "fc00::/18"
                  },
                  {
                    "type": "h3",
                    "tag": "dns-local",
                    "detour": "direct",
                    "server": "172.64.36.2",
                    "tls": {
                      "enabled": true,
                      "record_fragment": true,
                      "server_name": "${config.sops.placeholder.zerotrust}"
                    }
                  },
                  {
                    "type": "h3",
                    "tag": "dns-remote",
                    "detour": "oversea",
                    "server": "149.112.112.11",
                    "tls": {
                      "enabled": true,
                      "record_fragment": true,
                      "server_name": "dns11.quad9.net"
                    }
                  }
                ],
                "rules": [
                  {
                    "rule_set": "adblock-dns",
                    "action": "reject"
                  },
                  {
                    "type": "logical",
                    "mode": "or",
                    "rules": [
                      {
                        "domain": [
                          "localhost.ptlogin2.qq.com",
                          "localhost.sec.qq.com",
                          "proxy.golang.org",
                          "lens.l.google.com"
                        ]
                      },
                      {
                        "domain_suffix": [
                          ".lan",
                          ".localdomain",
                          ".example",
                          ".invalid",
                          ".localhost",
                          ".test",
                          ".local",
                          ".home.arpa",
                          ".msftconnecttest.com",
                          ".msftncsi.com",
                          ".music.163.com",
                          ".126.net",
                          ".kuwo.cn",
                          ".y.qq.com",
                          ".xiami.com",
                          ".music.migu.cn",
                          ".srv.nintendo.net",
                          ".stun.playstation.net",
                          ".xboxlive.com",
                          ".battlenet.com.cn",
                          ".wotgame.cn",
                          ".wggames.cn",
                          ".wowsgame.cn",
                          ".wargaming.net",
                          ".linksys.com",
                          ".linksyssmartwifi.com",
                          ".router.asus.com",
                          ".nflxvideo.net",
                          ".square-enix.com",
                          ".finalfantasyxiv.com",
                          ".ffxiv.com",
                          ".mcdn.bilivideo.cn",
                          "music.163.com",
                          "music.taihe.com",
                          "musicapi.taihe.com",
                          "songsearch.kugou.com",
                          "trackercdn.kugou.com",
                          "api.joox.com",
                          "joox.com",
                          "y.qq.com",
                          "music.migu.cn",
                          "msftconnecttest.com",
                          "msftncsi.com"
                        ]
                      },
                      {
                        "domain_keyword": [
                          "ntp",
                          "time",
                          "stun"
                        ]
                      },
                      {
                        "domain_regex": [
                          "^xbox\\..*\\.microsoft\\.com$"
                        ]
                      },
                      {
                        "rule_set": [
                          "geosite-private"
                        ]
                      }
                    ],
                    "server": "dns-local"
                  },
                  {
                    "query_type": [
                      "A",
                      "AAAA"
                    ],
                    "server": "fakeip"
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
                      "geosite-category-cryptocurrency",
                      "geosite-tld-cn",
                      "geosite-geolocation-cn",
                      "geosite-cn"
                    ],
                    "server": "dns-local"
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
                    "server": "dns-remote"
                  }
                ],
                "final": "dns-local",
                "strategy": "prefer_ipv4",
                "independent_cache": true
              },
              "endpoints": ${config.sops.placeholder.sing-box-endpoints},
              "inbounds": [
                {
                  "type": "direct",
                  "tag": "dns-in",
                  "listen": "127.0.0.1",
                  "listen_port": 53
                },
                {
                  "type": "tun",
                  "tag": "tun-in",
                  "interface_name": "tun0",
                  "address": [
                    "172.19.0.1/30",
                    "fdfe:dcba:9876::1/126"
                  ],
                  "auto_route": true,
                  "auto_redirect": true,
                  "strict_route": true,
                  "stack": "system"
                },
                {
                  "type": "mixed",
                  "tag": "mixed-in",
                  "listen": "127.0.0.1",
                  "listen_port": 2080
                }
              ],
              "outbounds": ${config.sops.placeholder.sing-box-outbounds},
              "route": {
                "rules": [
                  {
                    "inbound": [
                      "tun-in",
                      "mixed-in"
                    ],
                    "action": "resolve",
                    "strategy": "prefer_ipv4"
                  },
                  {
                    "inbound": [
                      "tun-in",
                      "mixed-in"
                    ],
                    "action": "sniff",
                    "timeout": "1s"
                  },
                  {
                    "type": "logical",
                    "mode": "or",
                    "rules": [
                      {
                        "inbound": "dns-in"
                      },
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
                    "action": "reject"
                  },
                  {
                    "type": "logical",
                    "mode": "or",
                    "rules": [
                      {
                        "ip_cidr": [
                          "224.0.0.0/3",
                          "10.0.0.0/8",
                          "172.16.0.0/12",
                          "192.168.0.0/16",
                          "fc00::/7",
                          "ff00::/8",
                          "fe80::/10"
                        ]
                      },
                      {
                        "rule_set": [
                          "geoip-private",
                          "geosite-private"
                        ]
                      }
                    ],
                    "outbound": "direct"
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
                        "domain_keyword": [
                          "tracker",
                          "announce",
                          "torrent"
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
                      "geosite-cn",
                      "geoip-cn"
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
                  }
                ],
                "final": "oversea",
                "auto_detect_interface": true,
                "default_domain_resolver": "dns-local"
              },
              "experimental": {
                "cache_file": {
                  "enabled": true,
                  "path": "cache.db",
                  "store_fakeip": true,
                  "store_rdrc": true
                },
                "clash_api": {
                  "external_controller": "0.0.0.0:9090",
                  "external_ui": "ui",
                  "secret": ""
                }
              }
            } 
          '';
        };
      };
    };
    networking.firewall = lib.mkMerge [
      # AdGuardHome 的端口规则
      (mkIf config.modules.proxy.enableAdGuardHome {
        allowedTCPPorts = [ 53 80 443 3000 ];
        allowedUDPPorts = [ 53 1080 67 68 547 546 ];
      })

      # dnscrypt-proxy 的端口规则
      (mkIf config.modules.proxy.enableDnsCryptProxy {
        allowedTCPPorts = [ 9007 ];
        allowedUDPPorts = [ 53 ];
      })

      # Sing-box 的端口规则
      (mkIf config.modules.proxy.enableSingbox {
        allowedTCPPorts = [ 1080 9090 ];
        allowedUDPPorts = [ 1080 ];
      })
    ];

    services.adguardhome.enable =
      mkIf config.modules.proxy.enableAdGuardHome true;
    systemd.services.adguardhome = mkIf config.modules.proxy.enableAdGuardHome {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      };
    };

    systemd.tmpfiles.rules = mkIf config.modules.proxy.enableDnsCryptProxy
      [ "d /var/lib/dnscrypt-proxy 0755 dnscrypt-proxy dnscrypt-proxy - -" ];
    systemd.services.update-dnscrypt-blocklist =
      mkIf config.modules.proxy.enableDnsCryptProxy {
        description = "Update dnscrypt-proxy blocklist";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        script = ''
          ${pkgs.curl}/bin/curl -L -o /var/lib/dnscrypt-proxy/blocklist.txt https://cdn.jsdelivr.net/gh/hydroakri/dnscrypt-proxy-blocklist@release/blocklist.txt
          # 如果需要，可以在这里重启服务或发送信号
          # systemctl kill -s HUP dnscrypt-proxy
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "dnscrypt-proxy";
        };
      };

    services.sing-box = mkIf config.modules.proxy.enableSingbox {
      enable = true;
      package = pkgs.sing-box;
    };
    systemd.services.sing-box = mkIf config.modules.proxy.enableSingbox {
      after = [ "network-online.target" ]
        ++ (lib.optional config.modules.proxy.enableAdGuardHome
          "adguardhome.service")
        ++ (lib.optional config.modules.proxy.enableDnsCryptProxy
          "dnscrypt-proxy.service");

      wants = [ "network-online.target" ]
        ++ (lib.optional config.modules.proxy.enableAdGuardHome
          "adguardhome.service")
        ++ (lib.optional config.modules.proxy.enableDnsCryptProxy
          "dnscrypt-proxy.service");

      restartTriggers = [ config.sops.templates."config.json".path ];

      serviceConfig.ExecStart = (lib.mkForce [
        ""
        "${pkgs.sing-box}/bin/sing-box run -c ${
          config.sops.templates."config.json".path
        }"
      ]);
    };

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
              qname(geosite:apple@cn, geosite:category-games-cn, geosite:category-game-accelerator-cn, geosite:category-game-platforms-download, geosite:category-pt, geosite:category-public-tracker, geosite:category-bank-cn, geosite:category-finance, geosite:category-securities-cn, geosite:tld-cn, geosite:geolocation-cn, geosite:cn, geosite:china-list) -> alih3
              fallback: localdns
            }
            response {
              !qname(geosite:tld-cn, geosite:geolocation-cn, geosite:cn) && qtype(aaaa) -> reject
              ip(geoip:private) && !qname(geosite:cn) -> flymc
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

          # bypass BT
          dscp(0x4) -> direct
          domain(keyword: tracker, announce, torrent) -> direct

          # set specific situation
          domain(geosite:google-cn, geosite:google, tradingview.com) -> proxy
          domain(geosite:apple@cn, geosite:category-games-cn, geosite:category-game-accelerator-cn, geosite:category-game-platforms-download, geosite:category-pt, geosite:category-public-tracker, geosite:category-bank-cn, geosite:category-finance, geosite:category-securities-cn) -> direct

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
