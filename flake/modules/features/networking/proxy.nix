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
      dohServerName = lib.mkOption {
        type = lib.types.oneOf [
          lib.types.str
          lib.types.attrs
        ];
        default = "cloudflare-dns.com";
        example = lib.literalExpression "{ _secret = config.sops.secrets.my-doh-hostname.path; }";
        description = ''
          TLS SNI / server_name used for the `dns-cloudflare` DoH server and as the
          `direct` outbound's domain resolver. Defaults to Cloudflare's real public
          DoH hostname (not a secret). Override with your own DoH gateway hostname
          (e.g. a private Cloudflare Zero Trust gateway) if you have one — this value
          is spliced directly into `services.sing-box.settings`, so if it needs to be
          secret, use sing-box's own `{ _secret = "/path/to/file"; }` mechanism
          (substituted by the upstream module's activation script), *not*
          `config.sops.placeholder.*` — sops-nix's placeholder substitution only
          applies inside `sops.templates.*.content` strings, not this option.
        '';
      };
      adblockRulesetUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://cdn.jsdelivr.net/gh/you/your-blocklist@release/blocklist.srs";
        description = ''
          URL of a remote sing-box `.srs` rule-set used to reject ad/tracker DNS
          queries. When null (default), no DNS-adblock rule/rule_set is added at
          all — the module ships no built-in blocklist.
        '';
      };
      localDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra domain_keyword entries routed to the local dns-unbound resolver.";
      };
      forceOverseasDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra domain_suffix entries always routed via the 'oversea' outbound.";
      };
      extraEndpoints = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = ''
          Extra sing-box `endpoints` entries (e.g. your own Tailscale/WireGuard peer
          definitions), spliced verbatim into `services.sing-box.settings.endpoints`.
          Any sensitive leaf value should use sing-box's native
          `{ _secret = "/path/to/file"; }` mechanism, sourced from a secret you
          declare in your own host config.
        '';
      };
      extraOutbounds = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = ''
          Extra sing-box `outbounds` entries (e.g. your VPN/proxy provider config),
          appended after the built-in selectors. When non-empty, this module also
          appends "isp"/"proxy"/"manual" to the built-in selector outbound lists, so
          your extra outbounds must define those tags to be selectable. Use
          `{ _secret = ...; }` for sensitive leaf values (keys, passwords).
        '';
      };
      endpointsFile = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.oneOf [
            lib.types.str
            lib.types.attrs
          ]
        );
        default = null;
        description = ''
          Path to a JSON file containing the entire sing-box `endpoints` array. When
          set, this replaces `extraEndpoints` entirely — the file's content is parsed
          as JSON at activation time and becomes `settings.endpoints`. Use sing-box's
          native `_secret` mechanism:

            endpointsFile = {
              _secret = config.sops.secrets.sing-box-endpoints.path;
              quote = false;
            };

          The file must contain a valid JSON array of endpoint objects. Requires
          `quote = false` so the content is injected as a JSON array, not a string.
        '';
      };
      outboundsFile = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.oneOf [
            lib.types.str
            lib.types.attrs
          ]
        );
        default = null;
        description = ''
          Path to a JSON file containing the entire sing-box `outbounds` array. When
          set, this replaces the built-in selectors AND `extraOutbounds` entirely —
          the file is parsed as JSON at activation time and becomes
          `settings.outbounds`. The file must contain all outbound objects including
          every tag referenced by route rules ("direct", "oversea", "cn",
          "ai-media-social", "webrtc-bt-proxy", and optionally "tailscale-out" if
          endpoints exist). Use sing-box's native `_secret` mechanism:

            outboundsFile = {
              _secret = config.sops.secrets.sing-box-outbounds.path;
              quote = false;
            };

          Requires `quote = false` so the content is injected as a JSON array.
        '';
      };
      tailscaleDirectDomains = lib.mkOption {
        type = lib.types.listOf (
          lib.types.oneOf [
            lib.types.str
            lib.types.attrs
          ]
        );
        default = [ ];
        description = ''
          Domains routed directly (not through Tailscale) when extraEndpoints/
          endpointsFile is set. Elements may be plain strings or sing-box
          `{ _secret = "/path"; }` markers (this list is spliced into
          `services.sing-box.settings`, not a sops.templates string — see
          dohServerName's option docs for why that distinction matters).
        '';
      };
      tailscaleDirectIps = lib.mkOption {
        type = lib.types.listOf (
          lib.types.oneOf [
            lib.types.str
            lib.types.attrs
          ]
        );
        default = [ ];
        description = ''
          IP CIDRs (e.g. "1.2.3.4/32", full prefix included) routed directly
          when extraEndpoints/endpointsFile is set. Elements may be plain
          strings or sing-box `{ _secret = "/path"; }` markers. Must include
          the prefix length yourself — this option no longer appends `/32`,
          since that Nix-level string interpolation can't run on a value only
          known at activation time (a `_secret` marker).
        '';
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
      extraDnsUpstreams = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = lib.literalExpression ''{ myresolver = "quic://dns.example.com:853"; }'';
        description = "Extra name -> upstream-URL entries appended to dae's dns.upstream block.";
      };
      extraOverseasDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra domain()/geosite matchers always routed via dae's proxy group.";
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

          webtunnel is compiled into tor since 0.4.8, so bridge lines using the
          built-in webtunnel transport need no ClientTransportPlugin entry —
          just paste the bridge line verbatim.

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
      hasExtraEndpoints =
        config.modules.proxy.singbox.extraEndpoints != [ ]
        || config.modules.proxy.singbox.endpointsFile != null;
      hasExtraOutbounds = config.modules.proxy.singbox.extraOutbounds != [ ];
      extraSelectorTags =
        lib.optional hasExtraOutbounds "isp"
        ++ lib.optional hasExtraOutbounds "proxy"
        ++ lib.optional hasExtraOutbounds "manual";
      anonSelectorTags = lib.optional config.modules.proxy.tor.enable "tor";
    in
    mkIf config.modules.proxy.enable {
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

      # sing-box: native structured config via services.sing-box.settings (a real
      # Nix attrset, not a JSON string). `{ _secret = "/path"; }` leaves are
      # substituted at activation time by the upstream module itself; this
      # module declares none, since every value below is public or an
      # extension-point option.
      services.sing-box = mkIf config.modules.proxy.singbox.enable {
        enable = mkDefault true;
        # withNaiveOutbound disabled: cronet-go fails to build on aarch64 on
        # the current nixpkgs pin (libc++/clang locale errors in vendored
        # Chromium sources). Unused anyway — nothing here references naive.
        package = pkgs.pkgsMusl.sing-box.override { withNaiveOutbound = false; };
        settings = {
          log = {
            level = "warn";
            timestamp = true;
          };
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
                type = "udp";
                tag = "dns-unbound";
                server = "127.0.0.1";
                server_port = 53;
              }
              {
                type = "h3";
                tag = "dns-alidns";
                server = "223.6.6.6";
                detour = "cn";
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
              # server_name defaults to Cloudflare's public DoH hostname (see
              # modules.proxy.singbox.dohServerName); the direct outbound's
              # domain_resolver below also depends on this server existing.
              {
                type = "h3";
                tag = "dns-cloudflare";
                server = "172.64.36.2";
                tls = {
                  enabled = true;
                  record_fragment = true;
                  server_name = config.modules.proxy.singbox.dohServerName;
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
                detour = "oversea";
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
            rules =
              (lib.optional (config.modules.proxy.singbox.adblockRulesetUrl != null) {
                rule_set = "adblock-dns";
                action = "reject";
              })
              ++ [
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
                      ]
                      ++ config.modules.proxy.singbox.localDomains;
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
                  server = "dns-unbound";
                }
                # CN 域名解析器选择：桌面 (unbound 可用) 用 dns-alidns（H3 加密，
                # detour:cn 直连阿里 DNS PoP，GeoDNS 覆盖好）。
                {
                  rule_set = [
                    "geosite-tld-cn"
                    "geosite-geolocation-cn"
                    "geosite-cn"
                  ];
                  server = "dns-alidns";
                }
                {
                  query_type = [
                    "A"
                    "AAAA"
                  ];
                  server = "fakeip";
                }
              ];
            # final：处理未被任何规则匹配的查询。用 dns-quad9 (detour:oversea)，加密防污染。
            final = "dns-quad9";
            strategy = "prefer_ipv4";
            cache_capacity = 4096;
            reverse_mapping = false;
          };

          endpoints =
            if config.modules.proxy.singbox.endpointsFile != null then
              config.modules.proxy.singbox.endpointsFile
            else
              config.modules.proxy.singbox.extraEndpoints;

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
            auto_route = true;
            auto_redirect = true;
            strict_route = true;
            exclude_mptcp = true;
            stack = "mixed";
            exclude_uid_range = [
              "${toString config.users.users.root.uid}:${toString config.users.users.root.uid}"
              "${toString config.users.users.unbound.uid}:${toString config.users.users.unbound.uid}"
              "${toString config.users.users.dnscrypt-proxy.uid}:${toString config.users.users.dnscrypt-proxy.uid}"
            ]
            ++ (lib.optional config.modules.proxy.tor.enable "${toString config.users.users.tor.uid}:${toString config.users.users.tor.uid}");
          };

          outbounds =
            if config.modules.proxy.singbox.outboundsFile != null then
              config.modules.proxy.singbox.outboundsFile
            else
              [
                {
                  type = "direct";
                  tag = "direct";
                  udp_fragment = true;
                  tcp_multi_path = true;
                  # direct.domain_resolver：仅在 SOCKS/HTTP 代理模式下 direct outbound 收到
                  # 域名目标时触发。用 dns-cloudflare (https, 无 detour)：DoH over TCP，
                  # 国内直连可用，防 GFW 污染。
                  domain_resolver = {
                    server = "dns-cloudflare";
                    strategy = "prefer_ipv4";
                  };
                }
              ]
              ++ (lib.optional config.modules.proxy.tor.enable {
                type = "socks";
                tag = "zerotrust";
                server = "127.0.0.1";
                server_port = 40000;
              })
              # 匿名出站：tor (9050) 本地 SOCKS。域名目标原样走
              # SOCKS5 握手（tor 自己解析 .onion），
              # sing-box 不会先解析，无 DNS 泄漏。
              ++ (lib.optional config.modules.proxy.tor.enable {
                type = "socks";
                tag = "tor";
                server = "127.0.0.1";
                server_port = 9050;
              })
              ++ [
                {
                  type = "selector";
                  tag = "cn";
                  outbounds = [ "direct" ] ++ extraSelectorTags ++ anonSelectorTags;
                }
                {
                  type = "selector";
                  tag = "oversea";
                  outbounds = [ "direct" ] ++ extraSelectorTags ++ anonSelectorTags;
                }
                {
                  type = "selector";
                  tag = "ai-media-social";
                  outbounds = [
                    "direct"
                  ]
                  ++ (lib.optional hasExtraOutbounds "isp")
                  ++ (lib.optional hasExtraOutbounds "manual")
                  ++ anonSelectorTags;
                }
                {
                  type = "selector";
                  tag = "webrtc-bt-proxy";
                  outbounds = [ "direct" ] ++ extraSelectorTags ++ anonSelectorTags;
                }
              ]
              ++ lib.optional hasExtraEndpoints {
                type = "selector";
                tag = "tailscale-out";
                outbounds = [ "direct" ] ++ extraSelectorTags ++ anonSelectorTags;
              }
              ++ config.modules.proxy.singbox.extraOutbounds;

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
            ]
            ++ (lib.optional (config.modules.proxy.singbox.adblockRulesetUrl != null) {
              rule_set = "adblock-dns";
              action = "reject";
              method = "drop";
            })
            ++ (lib.optionals hasExtraEndpoints [
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
                ]
                ++ (lib.optional (config.modules.proxy.singbox.tailscaleDirectDomains != [ ]) {
                  domain = config.modules.proxy.singbox.tailscaleDirectDomains;
                })
                ++ (lib.optional (config.modules.proxy.singbox.tailscaleDirectIps != [ ]) {
                  ip_cidr = config.modules.proxy.singbox.tailscaleDirectIps;
                });
                outbound = "tailscale-out";
              }
            ])
            ++ [
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
                outbound = "webrtc-bt-proxy";
              }
            ]
            # 匿名域名直送本地 SOCKS：.onion 由 tor 解析（fakeip 会先兜底 A/AAAA 查询，路由按
            # 反查出的域名匹配）。必须排在各 catch-all（oversea/cn/geoip）之前。注意
            # 必须用 ++ 拼接：lib.optional 返回的是 list，直接嵌进 [...] 会生成嵌套
            # 数组导致 sing-box 启动失败。
            ++ (lib.optional config.modules.proxy.tor.enable {
              domain_suffix = [ ".onion" ];
              outbound = "tor";
            })
            ++ [
              {
                type = "logical";
                mode = "or";
                rules =
                  (lib.optional (config.modules.proxy.singbox.forceOverseasDomains != [ ]) {
                    domain_suffix = config.modules.proxy.singbox.forceOverseasDomains;
                  })
                  ++ [
                    {
                      rule_set = [
                        "geosite-google"
                        "geosite-google-cn"
                      ];
                    }
                  ];
                outbound = "oversea";
              }
              {
                rule_set = [
                  "geosite-category-ai-chat-!cn"
                  "geosite-category-ai-!cn"
                  "geosite-category-ai-chat-!cn@!cn"
                  "geosite-category-media"
                  "geosite-category-entertainment"
                  "geosite-category-entertainment@!cn"
                  "geosite-category-emby"
                  "geosite-category-social-media-!cn"
                  "geosite-category-social-media-!cn@cn"
                ];
                outbound = "ai-media-social";
              }
              {
                rule_set = [
                  "geosite-apple@cn"
                  "geosite-category-games-cn"
                  "geosite-category-game-accelerator-cn"
                  "geosite-category-game-platforms-download"
                  "geosite-category-bank-cn"
                  "geosite-category-finance"
                  "geosite-category-securities-cn"
                  "geosite-category-cryptocurrency"
                  "geosite-category-ecommerce"
                ];
                outbound = "direct";
              }
              {
                rule_set = [
                  "geosite-gfw"
                  "geosite-geolocation-!cn"
                ];
                outbound = "oversea";
              }
              {
                rule_set = [ "geoip-cn" ];
                outbound = "cn";
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
                outbound = "oversea";
              }
              {
                rule_set = [
                  "geosite-tld-cn"
                  "geosite-geolocation-cn"
                  "geosite-cn"
                ];
                outbound = "cn";
              }
            ];
            rule_set =
              (lib.optional (config.modules.proxy.singbox.adblockRulesetUrl != null) {
                type = "remote";
                tag = "adblock-dns";
                url = config.modules.proxy.singbox.adblockRulesetUrl;
                update_interval = "24h0m0s";
              })
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
                  "geosite-google-cn"
                  "geosite-google"
                  "geosite-apple@cn"
                  "geosite-category-games-cn"
                  "geosite-category-game-accelerator-cn"
                  "geosite-category-game-platforms-download"
                  "geosite-category-pt"
                  "geosite-category-public-tracker"
                  "geosite-category-bank-cn"
                  "geosite-category-finance"
                  "geosite-category-securities-cn"
                  "geosite-category-ecommerce"
                  "geosite-gfw"
                  "geosite-geolocation-!cn"
                  "geosite-tld-cn"
                  "geosite-geolocation-cn"
                  "geosite-cn"
                  "geosite-category-cryptocurrency"
                  "geosite-category-ai-chat-!cn"
                  "geosite-category-ai-!cn"
                  "geosite-category-ai-chat-!cn@!cn"
                  "geosite-category-media"
                  "geosite-category-entertainment"
                  "geosite-category-entertainment@!cn"
                  "geosite-category-emby"
                  "geosite-category-social-media-!cn"
                  "geosite-category-social-media-!cn@cn"
                  "geosite-tailscale"
                ]
              );
            final = "oversea";
            auto_detect_interface = true;
            # default_domain_resolver：代理 outbound 解析服务器域名时的默认 resolver。
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
              store_rdrc = true;
            };
            clash_api = {
              external_controller = "127.0.0.1:9090";
              external_ui = "ui";
              external_ui_download_url = "https://github.com/MetaCubeX/metacubexd/archive/gh-pages.zip";
              external_ui_download_detour = "direct";
              secret = "";
            };
          };
        };
      };

      systemd.services.sing-box = mkIf config.modules.proxy.singbox.enable {
        after = [
          "network-online.target"
          "unbound.service"
          "dnscrypt-proxy.service"
        ]
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.tor.enable "tor.service");

        wants = [
          "network-online.target"
          "unbound.service"
          "dnscrypt-proxy.service"
        ]
        ++ (lib.optional config.modules.proxy.adguardhome.enable "adguardhome.service")
        ++ (lib.optional config.modules.proxy.tor.enable "tor.service");

        serviceConfig = {
          # sing-box 上游模块未加任何 systemd 沙箱；这里补上。
          # TUN 模式需要建立/配置虚拟网卡，因此需要 CAP_NET_ADMIN 和 netlink，且不能 PrivateDevices。
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
          # external_ui_download_url 会把面板 zip 先落到 /tmp 再解压；ProtectSystem=strict
          # 下 /tmp 默认只读，得靠 PrivateTmp 给它一个私有可写的 /tmp。
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
            extraUpstreamsText = lib.concatStrings (
              lib.mapAttrsToList (
                name: url: "      ${name}: '${url}'\n"
              ) config.modules.proxy.dae.extraDnsUpstreams
            );
            overseasDomains = lib.concatStringsSep ", " (
              [
                "geosite:google-cn"
                "geosite:google"
              ]
              ++ config.modules.proxy.dae.extraOverseasDomains
            );
            # dae 直连放行的本地代理进程；tor 自身的对外连接不能被
            # dae 重新接管（否则选中 tor 出站时形成 tor→dae→tor 回路）。
            directPnames = lib.concatStringsSep ", " (
              [
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
              ]
              ++ lib.optionals config.modules.proxy.tor.enable [ "tor" ]
            );
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
            ${extraUpstreamsText}  }
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
              domain(${overseasDomains}) -> proxy
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
