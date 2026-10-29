# nixos-rebuild boot --flake ./flake#rpi4-side-gateway --target-host root@<ip> --install-bootloader |& nom
# nh os switch -H rpi4-side-gateway ./flake
{
  inputs,
  ...
}:
{
  imports = [
    ../common.nix
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
    ../../modules/features/networking/proxy-nodes.nix
    ../../modules/features/utils.nix
    ../../modules/features/networking/router.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
  ];

  config = {
    modules.security.authorizedKeys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIORKNKURAriDLXiBpCKeuc3aBcIkQJy32I+sOpwMaWUmAAAABHNzaDo= hydroakri"
    ];
    modules = {
      proxy = {
        enable = true;
        singbox = {
          enable = true;
          tun = true;
        };
      };
      utils = {
        enable = true;
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

    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.hostName = "rpi4";
  };
}
