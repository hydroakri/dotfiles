# nixos-rebuild boot --flake .#rpi4 --target-host root@192.168.1.4 --install-bootloader |& nom
# nh os switch -H rpi4 ./
{ config, lib, pkgs, inputs, ... }: {
  imports = [
    # Hardware modules
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./hardware-configuration.nix
    ../../modules/hardware/rpi4-base.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/server.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix
    ../../modules/features/proxy.nix
    ../../modules/features/utils.nix
    ../../modules/features/router.nix

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
      router = {
        enable = true;
        wan = {
          interface = "end0";
          mtu = 1492;
        };
        lan = {
          interfaces = [];
          ipv4Address = null;
        };
        dhcp.enable = false;
        nat.enable = false;
        mssClamping = {
          enable = true;
          mss = 1412;
        };
        sysfsTuning = {
          rx = [ "end0" "wlan0" ];
          tx = [ "wlan0" ];
        };
      };
    };

    networking.hostName = "rpi4";
    networking.firewall.checkReversePath = false; # For dae transparent netgate, let date pass
  };
}
