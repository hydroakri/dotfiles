# nixos-rebuild boot --flake ./flake#rpi4-switch --target-host root@<ip> --install-bootloader |& nom
# nh os switch -H rpi4-switch ./flake
{
  lib,
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
    ../../modules/features/networking/proxy.nix
    ../../modules/features/utils.nix
    ../../modules/features/networking/router.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    mainUser = "hydroakri";
    modules.core = {
      extraSubstituters = [
        "https://cache.hydroakri.cc/cachix"
        "https://attic.xuyh0120.win/lantian"
      ];
      extraTrustedPublicKeys = [
        "cachix:RTT3Lx/HwP7OQwsaF6HpidQZvmpbu6xxa/Bc9CCp8zI="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      ];
    };
    modules.security = {
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAw4ah1WaneMXXpgSwKQ43GLuLDg+7FQOzg6+Sw0JgqIAAAABHNzaDo= nitrokey"
      ];
    };
    modules = {
      utils = {
        enable = false;
        enableGrafana = false;
        enablePrometheus = false;
        enableGraphicTools = false;
      };
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

    networking.hostName = "rpi4-switch";
    networking.firewall.allowedUDPPorts = [ 53 ];
    environment.etc."tuned/active_profile".text = lib.mkForce "network-throughput";
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
