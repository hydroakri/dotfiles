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
        default = "192.168.10.10,192.168.10.100,24h";
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

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.default.forwarding" = 1;

      "net.core.netdev_max_backlog" = lib.mkForce 2000;
      "net.core.rmem_max" = lib.mkForce 4194304;
      "net.core.wmem_max" = lib.mkForce 4194304;
      "net.ipv4.tcp_rmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_wmem" = lib.mkForce "4096 87380 4194304";
      "net.ipv4.tcp_mem" = lib.mkForce "4194304 4194304 4194304";
    };

    networking.vlans = lib.mkIf (cfg.wan.vlanId != null) {
      "vlan${toString cfg.wan.vlanId}" = {
        id = cfg.wan.vlanId;
        interface = cfg.wan.interface;
      };
    };

    networking.interfaces =
      (
        let
          wanIface = cfg.wan.interface;
          extIface = if (cfg.wan.vlanId != null) then "vlan${toString cfg.wan.vlanId}" else wanIface;
        in
        {
          ${wanIface} = lib.mkMerge [
            (lib.mkIf (cfg.wan.vlanId != null) { useDHCP = false; })
            (lib.mkIf (cfg.wan.vlanId == null) { useDHCP = cfg.wan.useDHCP; })
            (lib.mkIf (cfg.wan.mtu != null) { mtu = cfg.wan.mtu; })
          ];
        }
        // lib.optionalAttrs (cfg.wan.vlanId != null) {
          ${extIface} = {
            useDHCP = cfg.wan.useDHCP;
          };
        }
      )
      // (
        if (cfg.lan.interfaces != [ ]) then
          (lib.listToAttrs (
            map (
              iface:
              lib.nameValuePair iface {
                useDHCP = false;
                ipv4.addresses = lib.mkIf (cfg.lan.ipv4Address != null) (
                  lib.mkForce [
                    {
                      address = cfg.lan.ipv4Address;
                      prefixLength = cfg.lan.ipv4PrefixLength;
                    }
                  ]
                );
              }
            ) cfg.lan.interfaces
          ))
        else
          { }
      );

    services.resolved.enable = lib.mkIf cfg.dhcp.enable (lib.mkForce false);
    services.dnsmasq = lib.mkIf cfg.dhcp.enable {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        interface = builtins.head cfg.lan.interfaces;
        bind-dynamic = true;
        dhcp-authoritative = true;
        enable-ra = true;
        dhcp-range = [
          cfg.dhcp.range
          "::,constructor:${builtins.head cfg.lan.interfaces},ra-stateless"
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

    networking.firewall.trustedInterfaces = cfg.lan.interfaces;

    networking.nat = lib.mkIf cfg.nat.enable {
      enable = true;
      externalInterface =
        if (cfg.wan.vlanId != null) then "vlan${toString cfg.wan.vlanId}" else cfg.wan.interface;
      internalInterfaces = cfg.lan.interfaces;
    };

    networking.firewall.extraCommands = lib.mkIf cfg.mssClamping.enable (
      let
        extIface = if (cfg.wan.vlanId != null) then "vlan${toString cfg.wan.vlanId}" else cfg.wan.interface;
        mssCmd =
          if (cfg.mssClamping.mss != null) then
            "-j TCPMSS --set-mss ${toString cfg.mssClamping.mss}"
          else
            "-j TCPMSS --clamp-mss-to-pmtu";
      in
      ''
        ${lib.optionalString (cfg.mssClamping.mss != null)
          "iptables -t mangle -D POSTROUTING -o ${extIface} -p tcp --tcp-flags SYN,RST SYN ${mssCmd} 2>/dev/null || true"
        }
        iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o ${extIface} ${mssCmd}
      ''
    );
  };
}
