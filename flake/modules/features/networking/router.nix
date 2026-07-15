{
  config,
  lib,
  pkgs,
  ...
}:

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
            parts = lib.splitString "." config.modules.router.lan.ipv4Address;
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

  config = lib.mkIf config.modules.router.enable (
    let
      # Use a helper to determine the actual WAN interface (VLAN or raw)
      extInterface =
        if (config.modules.router.wan.vlanId != null) then
          "vlan${toString config.modules.router.wan.vlanId}"
        else
          config.modules.router.wan.interface;
      # Primary LAN interface for DNS/DHCP binding
      lanPrimaryInterface =
        if (config.modules.router.lan.interfaces != [ ]) then
          builtins.head config.modules.router.lan.interfaces
        else
          null;
    in
    {
      assertions = [
        {
          assertion = config.modules.router.dhcp.enable -> lanPrimaryInterface != null;
          message = "modules.router.lan.interfaces must not be empty when DHCP is enabled.";
        }
        {
          assertion = config.modules.router.nat.enable -> lanPrimaryInterface != null;
          message = "modules.router.lan.interfaces must not be empty when NAT is enabled.";
        }
      ];

      # mkOverride 900: wins over server.nix's mkDefault "throughput-performance" by
      # default when both are imported, but still yields to a plain user assignment.
      environment.etc."tuned/active_profile".text = lib.mkOverride 900 "network-latency";
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = lib.mkOverride 950 1;
        "net.ipv6.conf.all.forwarding" = lib.mkOverride 950 1;
        "net.ipv6.conf.default.forwarding" = lib.mkOverride 950 1;
      };

      networking.vlans = lib.mkIf (config.modules.router.wan.vlanId != null) {
        ${extInterface} = {
          id = config.modules.router.wan.vlanId;
          interface = config.modules.router.wan.interface;
        };
      };

      networking.interfaces = {
        # Configure WAN physical interface
        ${config.modules.router.wan.interface} = lib.mkMerge [
          (lib.mkIf (config.modules.router.wan.vlanId != null) { useDHCP = false; })
          (lib.mkIf (config.modules.router.wan.vlanId == null) {
            useDHCP = config.modules.router.wan.useDHCP;
          })
          (lib.mkIf (config.modules.router.wan.mtu != null) { mtu = config.modules.router.wan.mtu; })
        ];
      }
      // lib.optionalAttrs (config.modules.router.wan.vlanId != null) {
        # Configure WAN VLAN interface
        ${extInterface} = {
          useDHCP = config.modules.router.wan.useDHCP;
        };
      }
      // (lib.listToAttrs (
        lib.imap0 (
          i: iface:
          lib.nameValuePair iface {
            useDHCP = false;
            ipv4.addresses = lib.mkIf (config.modules.router.lan.ipv4Address != null && i == 0) (
              lib.mkDefault [
                {
                  address = config.modules.router.lan.ipv4Address;
                  prefixLength = config.modules.router.lan.ipv4PrefixLength;
                }
              ]
            );
          }
        ) config.modules.router.lan.interfaces
      ));

      services.resolved.enable = lib.mkIf config.modules.router.dhcp.enable (lib.mkDefault false);
      services.dnsmasq = lib.mkIf config.modules.router.dhcp.enable {
        enable = lib.mkDefault true;
        resolveLocalQueries = lib.mkDefault false;
        settings = {
          interface = lanPrimaryInterface;
          bind-dynamic = lib.mkDefault true;
          dhcp-authoritative = lib.mkDefault true;
          enable-ra = lib.mkDefault true;
          dhcp-range = [
            config.modules.router.dhcp.range
            "::,constructor:${lanPrimaryInterface},ra-stateless"
          ];
          port = lib.mkDefault 0;
        };
      };

      systemd.services.dnsmasq = lib.mkIf config.modules.router.dhcp.enable {
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
        after = [ "network.target" ];
      };

      networking.firewall = {
        trustedInterfaces = config.modules.router.lan.interfaces;
        checkReversePath = lib.mkDefault false;
        extraCommands = lib.mkIf config.modules.router.mssClamping.enable (
          let
            mssCmd =
              if (config.modules.router.mssClamping.mss != null) then
                "-j TCPMSS --set-mss ${toString config.modules.router.mssClamping.mss}"
              else
                "-j TCPMSS --clamp-mss-to-pmtu";
          in
          ''
            ${lib.optionalString (config.modules.router.mssClamping.mss != null)
              "iptables -t mangle -D POSTROUTING -o ${extInterface} -p tcp --tcp-flags SYN,RST SYN ${mssCmd} 2>/dev/null || true"
            }
            iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o ${extInterface} ${mssCmd}
          ''
        );
      };

      networking.nat = lib.mkIf config.modules.router.nat.enable {
        enable = lib.mkDefault true;
        externalInterface = extInterface;
        internalInterfaces = config.modules.router.lan.interfaces;
      };
    }
  );
}
