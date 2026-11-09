{
  config,
  lib,
  ...
}:
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
  vlessTags = map (n: n.tag) vlessNodes;

  # One registered WARP identity per device; the tag is `warp-<device>`.
  warpDevices = [
    "omen15"
    "samsungpad"
    "pixel10pro"
    "iphonese3"
  ];
  warpSecretFields = [
    "private-key"
    "address"
    "peer-address"
    "peer-reserved"
  ];
  warpSecret = d: field: config.sops.secrets."warp-${d}-${field}".path;
  mkWarpEndpoint = d: {
    type = "wireguard";
    tag = "warp-${d}";
    mtu = 1280;
    address = {
      _secret = warpSecret d "address";
      quote = false;
    };
    private_key._secret = warpSecret d "private-key";
    peers = [
      {
        address._secret = warpSecret d "peer-address";
        port = 2408;
        # Cloudflare's shared WARP peer key (same for every device).
        public_key = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=";
        allowed_ips = [
          "0.0.0.0/0"
          "::/0"
        ];
        persistent_keepalive_interval = 25;
        reserved._secret = warpSecret d "peer-reserved";
      }
    ];
  };
  warpTags = map (d: "warp-${d}") warpDevices;
in
{
  config = lib.mkIf config.modules.proxy.enable {
    sops.secrets =
      lib.listToAttrs (
        lib.concatMap (
          d:
          map (field: {
            name = "warp-${d}-${field}";
            value.sopsFile = ../secrets/proxy-secrets.yaml;
          }) warpSecretFields
        ) warpDevices
      )
      // lib.listToAttrs (
        lib.concatMap (
          n:
          map (field: {
            name = "vless-${n.id}-${field}";
            value.sopsFile = ../secrets/proxy-secrets.yaml;
          }) vlessSecretFields
        ) vlessNodes
      );

    modules.proxy.singbox.extraEndpoints = map mkWarpEndpoint warpDevices;

    modules.proxy.singbox.extraOutbounds = map mkVlessOutbound vlessNodes;

    modules.proxy.singbox.extraIspOutbounds = warpTags ++ vlessTags;
    modules.proxy.singbox.extraProxyOutbounds = warpTags ++ vlessTags;
    modules.proxy.singbox.extraManualOutbounds = warpTags ++ vlessTags;
  };
}
