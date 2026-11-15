# nixos-rebuild boot --flake ./flake#rpi4-switch --target-host root@<ip> --install-bootloader |& nom
# nh os switch -H rpi4-switch ./flake
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    # Hardware modules
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./hardware-configuration.nix
    ./rpi4-base.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/server.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix
    ../../modules/features/privacy.nix
    ../../modules/features/utils.nix
    ../../modules/features/networking/router.nix
    ../../modules/features/home-assistant.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    mainUser = "hydroakri";
    modules.core = {
      extraSubstituters = [
        "https://cache.hydroakri.cc/cachix"
        "https://cache.lantian.pub/lantian"
      ];
      extraTrustedPublicKeys = [
        "cachix:RTT3Lx/HwP7OQwsaF6HpidQZvmpbu6xxa/Bc9CCp8zI="
        "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
      ];
    };
    modules.security = {
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAw4ah1WaneMXXpgSwKQ43GLuLDg+7FQOzg6+Sw0JgqIAAAABHNzaDo= nitrokey"
      ];
    };
    modules = {
      networking.sqm = {
        enable = true;
        wanInterface = "end0"; # 连路由器的口，控制上传
        lanInterface = "enp1s0u1"; # 连电脑的口，控制下载
        downloadBandwidth = "98mbit";
        uploadBandwidth = "23mbit";
      };
      networking.sysfsTuning = {
        enable = true;
        interfaces = {
          end0 = {
            rps_cpus = "f";
            xps_cpus = "f"; # 板载千兆口，bcmgenet 驱动有5条tx队列，多队列设备
          };
          enp1s0u1 = {
            rps_cpus = "f";
          };
        };
      };
      router = {
        enable = true;
        wan = {
          interface = "end0";
          vlanId = 10;
        };
        lan = {
          interfaces = [ "enp1s0u1" ];
          ipv4Address = "192.168.10.1";
          ipv4PrefixLength = 24;
        };
        dhcp = {
          enable = true;
        };
        nat.enable = true;
        mssClamping.enable = true;
      };
    };

    modules.homeAssistant = {
      enable = true;
      light = "light.color_1600";
      nextAlarm = "sensor.sleep_as_android_next_alarm";
      sleepEvent = "event.sleep_as_android_user_notification";
    };
    # HA's zeroconf binds 0.0.0.0:5353; while dnscrypt-proxy holds it the analytics component fails and onboarding cannot finish.
    services.dnscrypt-proxy.settings.listen_addresses = [ "127.0.0.1:5300" ];
    services.unbound.settings.forward-zone = [
      {
        name = ".";
        forward-addr = [ "127.0.0.1@5300" ];
        forward-first = false;
      }
    ];

    # Subnet router: remote tailnet nodes reach the LAN (HA, LIFX). Routes need approval in headscale.
    sops.secrets.headscale-authkey.sopsFile = ../../modules/features/secrets/proxy-secrets.yaml;
    services.tailscale = {
      enable = true;
      openFirewall = true;
      # Subnet router: forwarding sysctls no longer depend on router.nix alone.
      useRoutingFeatures = "server";
      authKeyFile = config.sops.secrets.headscale-authkey.path;
      # extraUpFlags only run at login; extraSetFlags re-apply on every boot.
      extraUpFlags = [ "--login-server=https://headscale.hydroakri.cc" ];
      extraSetFlags = [
        "--advertise-routes=192.168.10.0/24"
        # The Pi is the LAN resolver; keep tailscaled away from /etc/resolv.conf.
        "--accept-dns=false"
      ];
    };

    # Feeds that block datacenter IPs are fetched from this home WAN IP and pushed into Miniflux on oci.
    sops.secrets.miniflux_api_key.sopsFile = ../../modules/features/secrets/rpi4.yaml;
    systemd.services.miniflux-push-blocked = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        StateDirectory = "miniflux-push-blocked";
        LoadCredential = "miniflux_api_key:${config.sops.secrets.miniflux_api_key.path}";
        # FEED_ID is the Miniflux feed id: 14 = The Quietus, 20 = iFixit News
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.python3}/bin/python3 ${./miniflux-push-blocked.py}"
          "--key-file %d/miniflux_api_key"
          "--state-dir %S/miniflux-push-blocked"
          "14=https://thequietus.com/feed/"
          "20=https://www.ifixit.com/News/rss"
        ];
        TimeoutStartSec = "3min";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
    systemd.timers.miniflux-push-blocked = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "30min";
        RandomizedDelaySec = "3min";
      };
    };

    networking.hostName = "rpi4-switch";
    modules.server.tunedProfile = "network-throughput";
    networking.networkmanager.unmanaged = [
      "end0"
      "vlan10"
      "enp1s0u1"
    ];
    networking.wireless.enable = lib.mkForce false;

    networking.dhcpcd = {
      enable = true;
      extraConfig = ''
        noipv6rs
        interface vlan10
          ipv6rs
          ia_pd 1 enp1s0u1/0
          rebind
          noipv6ra_detach
      '';
    };
  };
}
