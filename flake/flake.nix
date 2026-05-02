{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
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
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
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

      templates = {
        ros2 = {
          path = ./templates/ros2;
          description = # use `nix flake init -t ~/dotfiles#ros2` OR `nix flake init -t 'github:hydroakri/dotfiles?dir=flake#ros2' --refresh` to init a ros project
            "Robust ROS 2 Humble development environment with GUI and FHS support";
        };
      };
    };
}
