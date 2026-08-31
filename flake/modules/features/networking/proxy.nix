{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];
  options.modules.proxy = {
    enable = lib.mkEnableOption "Enable customized proxy stack (Sing-box + Dae)";

    adguardhome.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable AdGuardHome as the DNS resolver backend.";
    };

    # dnscrypt-proxy 本身现在是 core.nix 常驻服务(所有主机都跑,含 server_names/
    # static 的固定条目),proxy.nix 这里不再有它自己的选项。

    singbox = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable sing-box as the proxy backend.";
      };
      tun = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable sing-box tun-in inbound.";
      };
    };

    dae = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable dae as the Tproxy backend.";
      };
      interfaces.wan = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "WAN interface for dae.";
      };
      interfaces.lan = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "LAN interface for dae.";
      };
    };

    # 匿名后端：Tor 跑一个本地 SOCKS5 守护进程 (127.0.0.1:9050 回环地址),
    # 由 sing-box 的 selector outbounds 选取。回环方向（sing-box -> socks 端口）不
    # 会经过 tun，无需特殊处理；反方向（tor 自己的对外连接）会被 tun/dae
    # 拦截，必须用 exclude_uid_range / pname(must_direct) 放行，见下文。
    # 注：i2pd 曾提供 .i2p 站点访问，但无 outproxy 能力无法访问明网，已移除。
    tor = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable a Tor client daemon (services.tor) exposing local SOCKS5 on 127.0.0.1:9050 for sing-box to select.";
      };
      bridges = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = lib.literalExpression ''[ "webtunnel 1.2.3.4:443 <fingerprint> url=https://example.com/somepath ver=0.0.2" ]'';
        description = ''
          Tor bridge lines, one per element, as distributed by BridgeDB (or your
          own bridge operator). `UseBridges = 1` is set automatically whenever
          this list is non-empty.

          These values land in `services.tor.settings`, which renders a plain
          torrc text file: there is no `_secret` substitution like sing-box has.
          If a bridge line has to stay out of your git repo, DON'T use this
          option — leave it empty and override `services.tor.settings` from a
          host-level `sops.templates` instead.
        '';
      };
    };
  };

  config =
    with lib;
    let
      # 每个 vless-reality 流媒体节点只有这 6 个字段是每台服务器独有的敏感
      # 信息，其余（type/flow/tls.enabled/utls/reality.enabled/packet_encoding）
      # 是这批节点共用的客户端协议参数，写死在 nix 里，见 mkVlessOutbound。
      vlessSecretFields = [
        "server"
        "port"
        "uuid"
        "sni"
        "pbk"
        "sid"
      ];
      vlessNodes = [
        {
          id = "us-05";
          tag = "🇺🇸 美国 05 BGP IPv6 流媒体";
        }
        {
          id = "jp-06";
          tag = "🇯🇵 日本 06 BGP IPv6 流媒体";
        }
        {
          id = "hk-08";
          tag = "🇭🇰 香港 08 BGP IPv6 流媒体";
        }
        {
          id = "sg-06";
          tag = "🇸🇬 新加坡 06 BGP IPv6 流媒体";
        }
      ];
      vlessSecretPath = id: field: config.sops.secrets."vless-${id}-${field}".path;
      mkVlessOutbound =
        { id, tag }:
        {
          type = "vless";
          inherit tag;
          server = {
            _secret = vlessSecretPath id "server";
          };
          server_port = {
            _secret = vlessSecretPath id "port";
            quote = false;
          };
          uuid = {
            _secret = vlessSecretPath id "uuid";
          };
          flow = "xtls-rprx-vision";
          tls = {
            enabled = true;
            server_name = {
              _secret = vlessSecretPath id "sni";
            };
            utls = {
              enabled = true;
              fingerprint = "edge";
            };
            reality = {
              enabled = true;
              public_key = {
                _secret = vlessSecretPath id "pbk";
              };
              short_id = {
                _secret = vlessSecretPath id "sid";
              };
            };
          };
          packet_encoding = "xudp";
        };
    in
    mkIf config.modules.proxy.enable {
      sops.secrets = {
        zerotrust.sopsFile = ../secrets/proxy-secrets.yaml;
        oracle_domain.sopsFile = ../secrets/proxy-secrets.yaml;
        oracle_ip.sopsFile = ../secrets/proxy-secrets.yaml;
        headscale-authkey.sopsFile = ../secrets/proxy-secrets.yaml;
        warp-address.sopsFile = ../secrets/proxy-secrets.yaml;
        warp-private-key.sopsFile = ../secrets/proxy-secrets.yaml;
        warp-peer-address.sopsFile = ../secrets/proxy-secrets.yaml;
        warp-peer-public-key.sopsFile = ../secrets/proxy-secrets.yaml;
        warp-peer-reserved.sopsFile = ../secrets/proxy-secrets.yaml;
      }
      // listToAttrs (
        concatMap (
          n:
          map (field: {
            name = "vless-${n.id}-${field}";
            value.sopsFile = ../secrets/proxy-secrets.yaml;
          }) vlessSecretFields
        ) vlessNodes
      );

      # 开启透明代理 (TUN/TProxy) 时需放松 rp_filter 以支持非对称路由（如游戏 UDP）
      # mkOverride 900: intentionally overrides security.nix's mkOverride 950.
      boot.kernel.sysctl = mkIf (config.modules.proxy.dae.enable || config.modules.proxy.singbox.tun) {
        "net.ipv4.conf.all.rp_filter" = mkOverride 900 2;
        "net.ipv4.conf.default.rp_filter" = mkOverride 900 2;
      };

      # ----------------------------------------------------------------------------
      # start order
      # 1. 配置 Sing-box 的启动顺序：如果在该机器上启用了 AdGuardHome，则等待其启动

      # 2. 配置 Dae 的启动顺序：等待 Sing-box 和 AdGuardHome（如果它们存在）
      # dnscrypt-proxy/unbound 现在是 core.nix 常驻服务,不用再按 enable 条件判断
      systemd.services.dae = mkIf config.modules.proxy.dae.enable {
        after = [
          "network-online.target"
          "unbound.service"
          "dnscrypt-proxy.service"
        ]
        ++ (lib.optional config.modules.proxy.singbox.enable "sing-box.service")
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.tor.enable "tor.service");

        wants = [
          "network-online.target"
          "unbound.service"
          "dnscrypt-proxy.service"
        ]
        ++ (lib.optional config.modules.proxy.singbox.enable "sing-box.service")
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.tor.enable "tor.service");
      };
      # start order
      # ----------------------------------------------------------------------------

      # dnscrypt-proxy 是 core.nix 常驻服务,系统级 DNS 已经在那边指向 unbound 了
      networking.networkmanager.insertNameservers = mkIf config.modules.proxy.adguardhome.enable [
        "127.0.0.1"
      ];

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

        # Sing-box 的端口规则
        (mkIf config.modules.proxy.singbox.enable {
          allowedTCPPorts = [
            1080
            9090
            9091
          ];
          allowedUDPPorts = [ 1080 ];
        })
      ];

      services.adguardhome.enable = mkIf config.modules.proxy.adguardhome.enable (mkDefault true);
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

      services.sing-box = mkIf config.modules.proxy.singbox.enable {
        enable = mkDefault true;
        settings = {
          log = {
            level = "warn";
            timestamp = true;
          };
          http_clients = [
            {
              tag = "spoofed-http";
              detour = "➡️ direct";
              tls = {
                enabled = true;
                utls = {
                  enabled = true;
                  fingerprint = "firefox";
                };
              };
              headers = {
                "User-Agent" = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0";
                "Accept-Language" = "en-US,en;q=0.5";
                "Accept" = "*/*";
                "TE" = "trailers";
                "Sec-Gpc" = "1";
              };
            }
          ];
          dns = {
            servers = [
              {
                type = "fakeip";
                tag = "fakeip";
                inet4_range = "198.18.0.0/15";
                inet6_range = "64:ff9b:1::/48";
              }
              {
                type = "local";
                tag = "dns-system";
              }
              {
                type = "mdns";
                tag = "dns-mdns";
              }
              {
                type = "h3";
                tag = "dns-alidns";
                server = "223.6.6.6";
                detour = "🚦 cn";
                tls = {
                  enabled = true;
                  record_fragment = true;
                  server_name = "dns.alidns.com";
                  curve_preferences = [
                    "X25519MLKEM768"
                    "X25519"
                  ];
                };
              }
              {
                type = "h3";
                tag = "dns-flymc";
                server = "43.154.154.162";
                detour = "🚦 cn";
                tls = {
                  enabled = true;
                  record_fragment = true;
                  server_name = "dns.flymc.cc";
                  curve_preferences = [
                    "X25519MLKEM768"
                    "X25519"
                  ];
                };
              }
              {
                type = "h3";
                tag = "dns-zerotrust";
                server = "172.64.36.2";
                tls = {
                  enabled = true;
                  record_fragment = true;
                  server_name = {
                    _secret = config.sops.secrets.zerotrust.path;
                  };
                  curve_preferences = [
                    "X25519MLKEM768"
                    "X25519"
                  ];
                };
              }
              {
                type = "h3";
                tag = "dns-quad9";
                server = "149.112.112.11";
                detour = "🚦 oversea";
                tls = {
                  enabled = true;
                  record_fragment = true;
                  server_name = "dns11.quad9.net";
                  curve_preferences = [
                    "X25519MLKEM768"
                    "X25519"
                  ];
                };
              }
            ];
            rules = [
              {
                rule_set = "adblock-dns";
                action = "reject";
              }
              {
                preferred_by = "dns-mdns";
                server = "dns-mdns";
              }
              {
                type = "logical";
                mode = "or";
                rules = [
                  {
                    domain_keyword = [
                      "msftconnecttest.com"
                      "msftncsi.com"
                      "linksys.com"
                      "linksyssmartwifi.com"
                    ];
                  }
                  {
                    domain_suffix = [
                      "wlan"
                      "intranet"
                      "private"
                      "domain"
                      "home"
                      "host"
                      "corp"
                    ];
                  }
                  {
                    rule_set = [ "geosite-private" ];
                  }
                ];
                server = "dns-system";
              }
              {
                rule_set = [
                  "geosite-tld-cn"
                  "geosite-geolocation-cn"
                  "geosite-cn"
                  "geosite-gfw"
                  "geosite-geolocation-!cn"
                  "geosite-category-ai-chat-!cn"
                  "geosite-category-media"
                  "geosite-category-entertainment"
                  "geosite-category-emby"
                  "geosite-category-social-media-!cn"
                  "geosite-apple@cn"
                  "geosite-category-finance"
                  "geosite-category-cryptocurrency"
                  "geosite-category-ecommerce"
                  "geosite-category-pt"
                  "geosite-category-public-tracker"
                  "geosite-category-game-platforms-download"
                  "geosite-tailscale"
                ];
                query_type = [
                  "A"
                  "AAAA"
                ];
                server = "fakeip";
              }
              {
                query_type = [
                  "A"
                  "AAAA"
                ];
                action = "evaluate";
                server = "dns-zerotrust";
                timeout = "5s";
                disable_optimistic_cache = true;
              }
              {
                rule_set = [ "geoip-cn" ];
                match_response = true;
                server = "dns-flymc";
              }
              {
                match_response = true;
                response_rcode = "NXDOMAIN";
                action = "respond";
              }
              {
                match_response = true;
                response_rcode = "SERVFAIL";
                action = "respond";
              }
              {
                query_type = [
                  "A"
                  "AAAA"
                ];
                server = "fakeip";
              }
            ];
            final = "dns-quad9";
            strategy = "prefer_ipv4";
            cache_capacity = 4096;
            reverse_mapping = false;
            timeout = "10s";
            optimistic = true;
          };

          endpoints = [
            {
              type = "tailscale";
              tag = "tailscale-in";
              auth_key = {
                _secret = config.sops.secrets.headscale-authkey.path;
              };
              control_url = "https://headscale.hydroakri.cc";
            }
            {
              type = "wireguard";
              tag = "wg-cloudflare-warp";
              mtu = 1280;
              address = {
                _secret = config.sops.secrets.warp-address.path;
                quote = false;
              };
              private_key = {
                _secret = config.sops.secrets.warp-private-key.path;
              };
              peers = [
                {
                  address = {
                    _secret = config.sops.secrets.warp-peer-address.path;
                  };
                  port = 2408;
                  public_key = {
                    _secret = config.sops.secrets.warp-peer-public-key.path;
                  };
                  allowed_ips = [
                    "0.0.0.0/0"
                    "::/0"
                  ];
                  persistent_keepalive_interval = 25;
                  reserved = {
                    _secret = config.sops.secrets.warp-peer-reserved.path;
                  };
                }
              ];
            }
          ];

          inbounds = [
            {
              type = "mixed";
              tag = "mixed-in";
              listen = "127.0.0.1";
              listen_port = 1080;
            }
          ]
          ++ lib.optional config.modules.proxy.singbox.tun {
            type = "tun";
            tag = "tun-in";
            interface_name = "tun0";
            mtu = 1280;
            address = [
              "172.19.0.1/30"
              "fdfe:dcba:9876::1/126"
            ];
            dns_mode = "hijack";
            auto_route = true;
            auto_redirect = true;
            strict_route = true;
            exclude_mptcp = true;
            stack = "mixed";
            route_exclude_address_set = [ "geoip-private" ];
            exclude_uid_range = [
              "${toString config.users.users.root.uid}:${toString config.users.users.root.uid}"
              "${toString config.users.users.unbound.uid}:${toString config.users.users.unbound.uid}"
              "${toString config.users.users.dnscrypt-proxy.uid}:${toString config.users.users.dnscrypt-proxy.uid}"
            ]
            ++ (lib.optional config.modules.proxy.tor.enable "${toString config.users.users.tor.uid}:${toString config.users.users.tor.uid}");
          };

          outbounds = [
            {
              type = "block";
              tag = "🚫 block";
            }
            {
              type = "direct";
              tag = "➡️ direct";
              udp_fragment = true;
              tcp_multi_path = true;
              tcp_fast_open = true;
              domain_resolver = {
                server = "dns-zerotrust";
                strategy = "prefer_ipv4";
              };
            }
            {
              type = "direct";
              tag = "🇨🇳 direct-cn";
              udp_fragment = true;
              tcp_multi_path = true;
              tcp_fast_open = true;
              domain_resolver = {
                server = "dns-alidns";
                strategy = "prefer_ipv4";
              };
            }
            {
              type = "socks";
              tag = "🔒 zerotrust";
              server = "127.0.0.1";
              server_port = 40000;
              network = "tcp"; # 本地 SOCKS5 不支持 UDP ASSOCIATE，显式禁掉避免静默丢包。
            }
            {
              type = "socks";
              tag = "🧅 tor";
              server = "127.0.0.1";
              server_port = 9050;
              network = "tcp"; # Tor 协议本身不支持 UDP。
            }
            {
              type = "selector";
              tag = "🚦 cn";
              outbounds = [
                "🇨🇳 direct-cn"
                "🎯 isp"
                "🎯 proxy"
                "🎯 manual"
                "🚫 block"
              ];
            }
            {
              type = "selector";
              tag = "🚦 oversea";
              outbounds = [
                "➡️ direct"
                "🎯 isp"
                "🎯 proxy"
                "🎯 manual"
                "🚫 block"
              ];
            }
            {
              type = "selector";
              tag = "🚦 i18n-service";
              outbounds = [
                "➡️ direct"
                "🎯 isp"
                "🎯 manual"
                "🚫 block"
              ];
            }
            {
              type = "selector";
              tag = "🚦 finance";
              outbounds = [
                "➡️ direct"
                "🎯 isp"
                "🎯 proxy"
                "🎯 manual"
                "🚫 block"
              ];
            }
            {
              type = "selector";
              tag = "🚦 webrtc-bt-proxy";
              outbounds = [
                "➡️ direct"
                "🎯 isp"
                "🎯 proxy"
                "🎯 manual"
                "🚫 block"
              ];
            }
            {
              type = "selector";
              tag = "🚦 tailscale-out";
              outbounds = [
                "➡️ direct"
                "🎯 isp"
                "🎯 proxy"
                "🎯 manual"
              ];
            }
            {
              type = "selector";
              tag = "🎯 isp";
              outbounds = [
                "🔒 zerotrust"
                "wg-cloudflare-warp"
              ]
              ++ (map (n: n.tag) vlessNodes);
            }
            {
              type = "selector";
              tag = "🎯 proxy";
              outbounds = [
                "🧅 tor"
                "🔒 zerotrust"
                "wg-cloudflare-warp"
              ]
              ++ (map (n: n.tag) vlessNodes);
            }
            {
              type = "selector";
              tag = "🎯 manual";
              outbounds = [
                "➡️ direct"
                "🇨🇳 direct-cn"
                "🧅 tor"
                "🔒 zerotrust"
                "wg-cloudflare-warp"
              ]
              ++ (map (n: n.tag) vlessNodes);
            }
          ]
          ++ (map mkVlessOutbound vlessNodes);

          route = {
            rules = [
              {
                inbound = (lib.optional config.modules.proxy.singbox.tun "tun-in") ++ [ "mixed-in" ];
                action = "sniff";
                timeout = "300ms";
              }
              {
                type = "logical";
                mode = "or";
                rules = [
                  { port = 53; }
                  { protocol = "dns"; }
                ];
                action = "hijack-dns";
              }
              {
                rule_set = "adblock-dns";
                action = "reject";
                method = "drop";
              }
              {
                ip_cidr = [
                  "100.64.0.0/10"
                  "fd7a:115c:a1e0::/48"
                ];
                outbound = "tailscale-in";
              }
              {
                type = "logical";
                mode = "or";
                rules = [
                  { rule_set = [ "geosite-tailscale" ]; }
                  # tailscaleDirectIps needs the full CIDR in the secret itself
                  # (e.g. "<ip>/32") — can't be appended in Nix since the value
                  # is only known at activation time.
                  { domain = [ { _secret = config.sops.secrets.oracle_domain.path; } ]; }
                  { ip_cidr = [ { _secret = config.sops.secrets.oracle_ip.path; } ]; }
                ];
                outbound = "🚦 tailscale-out";
              }
              {
                rule_set = [
                  "geoip-private"
                  "geosite-private"
                ];
                action = "bypass"; # Linux only option
              }
              {
                type = "logical";
                mode = "or";
                rules = [
                  {
                    protocol = [
                      "bittorrent"
                      "stun"
                    ];
                  }
                  {
                    rule_set = [
                      "geosite-category-pt"
                      "geosite-category-public-tracker"
                    ];
                  }
                ];
                outbound = "🚦 webrtc-bt-proxy";
              }
              {
                domain_suffix = [ ".onion" ];
                outbound = "🧅 tor";
              }
              {
                rule_set = [
                  "geosite-category-ai-chat-!cn"
                  "geosite-category-media"
                  "geosite-category-entertainment"
                  "geosite-category-emby"
                  "geosite-category-social-media-!cn"
                  "geosite-apple@cn"
                ];
                outbound = "🚦 i18n-service";
              }
              {
                rule_set = [ "geosite-gfw" ];
                outbound = "🚦 oversea";
              }
              {
                rule_set = [ "geosite-category-game-platforms-download" ];
                outbound = "➡️ direct";
              }
              {
                rule_set = [
                  "geosite-category-finance"
                  "geosite-category-cryptocurrency"
                  "geosite-category-ecommerce"
                ];
                outbound = "🚦 finance";
              }
              {
                rule_set = [
                  "geosite-gfw"
                  "geosite-geolocation-!cn"
                ];
                outbound = "🚦 oversea";
              }
              {
                rule_set = [ "geoip-cn" ];
                outbound = "🚦 cn";
              }
              {
                type = "logical";
                mode = "and";
                rules = [
                  { domain_regex = ".*"; }
                  {
                    rule_set = [
                      "geosite-tld-cn"
                      "geosite-geolocation-cn"
                      "geosite-cn"
                    ];
                    invert = true;
                  }
                ];
                outbound = "🚦 oversea";
              }
              {
                rule_set = [
                  "geosite-tld-cn"
                  "geosite-geolocation-cn"
                  "geosite-cn"
                ];
                outbound = "🚦 cn";
              }
            ];
            rule_set = [
              {
                type = "remote";
                tag = "adblock-dns";
                url = "https://cdn.jsdelivr.net/gh/hydroakri/dnscrypt-proxy-blocklist@release/blocklist.srs";
                update_interval = "24h0m0s";
              }
            ]
            # All public MetaCubeX/meta-rules-dat rule-sets follow
            # .../geo/{geoip|geosite}/{tag-without-that-prefix}.srs, so the URL is
            # derived from the tag rather than hand-repeated 29 times.
            ++ (map
              (
                tag:
                let
                  category = if lib.hasPrefix "geoip-" tag then "geoip" else "geosite";
                  name = lib.removePrefix "${category}-" tag;
                in
                {
                  type = "remote";
                  inherit tag;
                  url = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/${category}/${name}.srs";
                  update_interval = "24h0m0s";
                }
              )
              [
                "geoip-private"
                "geoip-cn"
                "geosite-private"
                "geosite-apple@cn"
                "geosite-category-game-platforms-download"
                "geosite-category-pt"
                "geosite-category-public-tracker"
                "geosite-category-finance"
                "geosite-category-ecommerce"
                "geosite-gfw"
                "geosite-geolocation-!cn"
                "geosite-tld-cn"
                "geosite-geolocation-cn"
                "geosite-cn"
                "geosite-category-cryptocurrency"
                "geosite-category-ai-chat-!cn"
                "geosite-category-media"
                "geosite-category-entertainment"
                "geosite-category-emby"
                "geosite-category-social-media-!cn"
                "geosite-tailscale"
              ]
            );
            final = "🚦 oversea";
            auto_detect_interface = true;
            default_http_client = "spoofed-http";
            default_domain_resolver = {
              server = "dns-quad9";
              strategy = "prefer_ipv4";
            };
          };

          experimental = {
            cache_file = {
              enabled = true;
              path = "cache.db";
              store_fakeip = true;
              store_dns = true;
            };
          };
          services = [
            {
              type = "api";
              listen = "127.0.0.1";
              listen_port = 9091;
              secret = "";
              dashboard = {
                enabled = true;
              };
            }
          ];
        };
      };

      systemd.services.sing-box = mkIf config.modules.proxy.singbox.enable {
        after = [
          "network-online.target"
          "unbound.service"
          "dnscrypt-proxy.service"
          "tor.service"
        ]
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service");

        wants = [
          "network-online.target"
          "unbound.service"
          "dnscrypt-proxy.service"
          "tor.service"
        ]
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service");

        serviceConfig = {
          AmbientCapabilities = lib.optionals config.modules.proxy.singbox.tun [ "CAP_NET_ADMIN" ];
          CapabilityBoundingSet = lib.optionals config.modules.proxy.singbox.tun [ "CAP_NET_ADMIN" ];
          DeviceAllow = lib.optionals config.modules.proxy.singbox.tun [ "/dev/net/tun rw" ];
          PrivateDevices = !config.modules.proxy.singbox.tun;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ]
          ++ lib.optionals config.modules.proxy.singbox.tun [ "AF_NETLINK" ];
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          PrivateTmp = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          MemoryDenyWriteExecute = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
        };
      };

      # ----------------------------------------------------------------------------
      # 匿名后端：tor 客户端守护进程。只暴露回环 SOCKS5 给 sing-box,
      # 不开防火墙端口。持久化在 preservation.nix 处理（/var/lib/tor）。
      services.tor = mkIf config.modules.proxy.tor.enable {
        enable = mkDefault true;
        # 仅客户端角色：SOCKS 监听 127.0.0.1:9050（上游默认）。不做 relay/exit。
        client.enable = mkDefault true;
        settings = mkIf (config.modules.proxy.tor.bridges != [ ]) {
          UseBridges = true;
          Bridge = config.modules.proxy.tor.bridges;
        };
      };

      # ----------------------------------------------------------------------------

      services.dae = mkIf config.modules.proxy.dae.enable {
        enable = mkDefault true;
        assetsPath = toString (
          pkgs.symlinkJoin {
            name = "dae-assets";
            paths = [ "${inputs.geodb}" ];
          }
        );
        config =
          let
            # dae 直连放行的本地代理进程；tor 自身的对外连接不能被
            # dae 重新接管（否则选中 tor 出站时形成 tor→dae→tor 回路）。tor 不按
            # tor.enable 判断——没开时进程根本不存在，这条 pname 规则只是空放行。
            directPnames = lib.concatStringsSep ", " [
              "NetworkManager"
              "chronyd"
              "dnscrypt-proxy"
              "AdGuardHome"
              "nekoray"
              "nekobox_core"
              "sing-box"
              "verge-mihomo"
              "clash-verge"
              "clash-verge-service"
              "tor"
            ];
          in
          ''
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
                localdns: 'udp://127.0.0.1:53'
                flymc: 'quic://dns.flymc.cc:853'
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
              pname(${directPnames}) -> must_direct
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
