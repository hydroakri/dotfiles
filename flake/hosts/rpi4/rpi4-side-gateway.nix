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
        enableAdGuardHome = false;
        enableDnsCryptProxy = true;
        singbox.enable = true;
        dae = {
          enable = true;
          interfaces = {
            wan = "end0";
            lan = "end0";
          };
        };
      };
      utils = {
        enable = true;
        enableGlance = true;
        enableGrafana = true;
        enablePrometheus = true;
        enableGraphicTools = false;
      };
      networking.sysfsTuning = {
        enable = true;
        interfaces = {
          end0 = {
            rps_cpus = "f";
          };
          wlan0 = {
            rps_cpus = "f";
            xps_cpus = "f";
          };
        };
      };
      router = {
        enable = true;
        wan = {
          interface = "end0";
          mtu = 1492;
        };
        lan = {
          interfaces = [ ];
          ipv4Address = null;
        };
        dhcp.enable = false;
        nat.enable = false;
        mssClamping = {
          enable = true;
          mss = 1412;
        };
      };
    };

    networking.hostName = "rpi4";
    networking.firewall.checkReversePath = false; # For dae transparent netgate, let date pass
  };
}
