{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.router;
in
{
  options.modules.router = {
    enable = lib.mkEnableOption "router functionality";

    wan = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "end0";
        description = "WAN interface";
      };
      vlanId = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "VLAN ID for WAN";
      };
      mtu = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "MTU for WAN interface";
      };
      useDHCP = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use DHCP on WAN interface";
      };
    };

    lan = {
      interfaces = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "LAN interfaces";
      };
      ipv4Address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "192.168.10.1";
        description = "LAN IPv4 address";
      };
      ipv4PrefixLength = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "LAN IPv4 prefix length";
      };
    };

    dhcp = {
      enable = lib.mkEnableOption "DHCP server (dnsmasq)";
      range = lib.mkOption {
        type = lib.types.str;
        default =
          let
            parts = lib.splitString "." cfg.lan.ipv4Address;
            prefix = lib.concatStringsSep "." (lib.take 3 parts);
          in
          "${prefix}.10,${prefix}.100,24h";
        description = "DHCP range";
      };
    };

    nat = {
      enable = lib.mkEnableOption "NAT routing";
    };

    mssClamping = {
      enable = lib.mkEnableOption "MSS clamping";
      mss = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null; # null means clamp-mss-to-pmtu
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # Use a helper to determine the actual WAN interface (VLAN or raw)
      extInterface =
        if (cfg.wan.vlanId != null) then "vlan${toString cfg.wan.vlanId}" else cfg.wan.interface;
      # Primary LAN interface for DNS/DHCP binding
      lanPrimaryInterface =
        if (cfg.lan.interfaces != [ ]) then builtins.head cfg.lan.interfaces else null;
    in
    {
      assertions = [
        {
          assertion = cfg.dhcp.enable -> lanPrimaryInterface != null;
          message = "modules.router.lan.interfaces must not be empty when DHCP is enabled.";
        }
        {
          assertion = cfg.nat.enable -> lanPrimaryInterface != null;
          message = "modules.router.lan.interfaces must not be empty when NAT is enabled.";
        }
      ];

      environment.etc."tuned/active_profile".text = lib.mkForce "network-latency";
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
        "net.ipv6.conf.default.forwarding" = 1;
      };

      networking.vlans = lib.mkIf (cfg.wan.vlanId != null) {
        ${extInterface} = {
          id = cfg.wan.vlanId;
          interface = cfg.wan.interface;
        };
      };

      networking.interfaces = {
        # Configure WAN physical interface
        ${cfg.wan.interface} = lib.mkMerge [
          (lib.mkIf (cfg.wan.vlanId != null) { useDHCP = false; })
          (lib.mkIf (cfg.wan.vlanId == null) { useDHCP = cfg.wan.useDHCP; })
          (lib.mkIf (cfg.wan.mtu != null) { mtu = cfg.wan.mtu; })
        ];
      }
      // lib.optionalAttrs (cfg.wan.vlanId != null) {
        # Configure WAN VLAN interface
        ${extInterface} = {
          useDHCP = cfg.wan.useDHCP;
        };
      }
      // (lib.listToAttrs (
        lib.imap0 (
          i: iface:
          lib.nameValuePair iface {
            useDHCP = false;
            ipv4.addresses = lib.mkIf (cfg.lan.ipv4Address != null && i == 0) (
              lib.mkDefault [
                {
                  address = cfg.lan.ipv4Address;
                  prefixLength = cfg.lan.ipv4PrefixLength;
                }
              ]
            );
          }
        ) cfg.lan.interfaces
      ));

      services.resolved.enable = lib.mkIf cfg.dhcp.enable (lib.mkForce false);
      services.dnsmasq = lib.mkIf cfg.dhcp.enable {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          interface = lanPrimaryInterface;
          bind-dynamic = true;
          dhcp-authoritative = true;
          enable-ra = true;
          dhcp-range = [
            cfg.dhcp.range
            "::,constructor:${lanPrimaryInterface},ra-stateless"
          ];
          port = 0;
        };
      };

      systemd.services.dnsmasq = lib.mkIf cfg.dhcp.enable {
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
        after = [ "network.target" ];
      };

      networking.firewall = {
        trustedInterfaces = cfg.lan.interfaces;
        checkReversePath = false;
        extraCommands = lib.mkIf cfg.mssClamping.enable (
          let
            mssCmd =
              if (cfg.mssClamping.mss != null) then
                "-j TCPMSS --set-mss ${toString cfg.mssClamping.mss}"
              else
                "-j TCPMSS --clamp-mss-to-pmtu";
          in
          ''
            ${lib.optionalString (cfg.mssClamping.mss != null)
              "iptables -t mangle -D POSTROUTING -o ${extInterface} -p tcp --tcp-flags SYN,RST SYN ${mssCmd} 2>/dev/null || true"
            }
            iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o ${extInterface} ${mssCmd}
          ''
        );
      };

      networking.nat = lib.mkIf cfg.nat.enable {
        enable = true;
        externalInterface = extInterface;
        internalInterfaces = cfg.lan.interfaces;
      };
    }
  );
}
