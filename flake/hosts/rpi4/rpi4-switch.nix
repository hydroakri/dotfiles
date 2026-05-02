# nixos-rebuild boot --flake .#rpi4 --target-host root@192.168.1.4 --install-bootloader |& nom
# nh os switch -H rpi4 ./
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
    ../../modules/features/networking/proxy.nix
    ../../modules/features/utils.nix
    ../../modules/features/networking/router.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    modules = {
      proxy = {
        enable = true;
        singbox.enable = true;
        singbox.dns = true;
      };
      utils = {
        enable = false;
        enableGlance = false;
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
          };
          enp1s0u1 = {
            rps_cpus = "f";
            xps_cpus = "f";
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
      '';
    };
  };
}
