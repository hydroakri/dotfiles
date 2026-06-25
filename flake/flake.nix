{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    geodb = {
      url = "github:Loyalsoldier/v2ray-rules-dat/release";
      flake = false;
    };
    dnscrypt-blocklist = {
      type = "file";
      url = "https://raw.githubusercontent.com/hydroakri/dnscrypt-proxy-blocklist/release/blocklist.txt";
      flake = false;
    };
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent = {
      url = "github:nousresearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      nixos-hardware,
      nix-index-database,
      nixos-generators,
      geodb,
      nix-minecraft,
      hermes-agent,
      nix-cachyos-kernel,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;

      # Make inputs available to all modules
      specialArgsForAll = { inherit inputs; };

    in
    {
      nixosConfigurations = {
        omen15 = lib.nixosSystem {
          specialArgs = specialArgsForAll;
          modules = [ ./hosts/omen15/omen15.nix ];
        };
        rpi4-side-gateway = lib.nixosSystem {
          specialArgs = specialArgsForAll;
          modules = [ ./hosts/rpi4/rpi4-side-gateway.nix ];
        };
        rpi4-switch = lib.nixosSystem {
          specialArgs = specialArgsForAll;
          modules = [ ./hosts/rpi4/rpi4-switch.nix ];
        };
        oci = lib.nixosSystem {
          specialArgs = specialArgsForAll;
          modules = [ ./hosts/oci/oci.nix ];
        };
      };

      packages = {
        x86_64-linux = {
          iso-installer = nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            specialArgs = specialArgsForAll;
            modules = [ ./hosts/isolive/isolive.nix ];
            format = "install-iso";
          };
        };
        aarch64-linux = {
          rpi-image = nixos-generators.nixosGenerate {
            system = "aarch64-linux";
            specialArgs = specialArgsForAll;
            modules = [ ./hosts/rpi-image/rpi-image.nix ];
            format = "sd-aarch64";
          };
        };
      };

      nixosModules = {
        # Base profiles (pick one per host)
        core = ./modules/core.nix;
        desktop = ./modules/desktop.nix;
        server = ./modules/server.nix;
        # Feature modules (opt-in)
        performance = ./modules/features/performance.nix;
        security = ./modules/features/security.nix;
        powersave = ./modules/features/powersave.nix;
        gaming = ./modules/features/gaming.nix;
        utils = ./modules/features/utils.nix;
        virtualisation = ./modules/features/virtualisation.nix;
        networking-proxy = ./modules/features/networking/proxy.nix;
        networking-router = ./modules/features/networking/router.nix;
        networking-sqm = ./modules/features/networking/sqm.nix;
        networking-tuning = ./modules/features/networking/tuning.nix;
        # Hardware / filesystem helpers
        hardware-amd = ./modules/hardware/amd.nix;
        hardware-nvidia = ./modules/hardware/nvidia.nix;
        filesystem-btrfs = ./modules/filesystems/btrfs.nix;
      };

      templates = {
        ros2 = {
          path = ./templates/ros2;
          description = # use `nix flake init -t ~/dotfiles#ros2` OR `nix flake init -t 'github:hydroakri/dotfiles?dir=flake#ros2' --refresh` to init a ros project
            "Robust ROS 2 Humble development environment with GUI and FHS support";
        };
      };
    };
}
