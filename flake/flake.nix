{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    adlist = {
      url =
        "https://cdn.jsdelivr.net/gh/hydroakri/dnscrypt-proxy-blocklist@release/blocklist.txt";
      flake = false;
    };
    geodb = {
      url = "github:Loyalsoldier/v2ray-rules-dat/release";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, sops-nix, nixos-hardware, nix-index-database
    , adlist, geodb, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # Make inputs available to all modules
      specialArgsForAll = { inherit inputs; };

    in {
      nixosConfigurations = {
        omen15 = lib.nixosSystem {
          specialArgs = specialArgsForAll;
          modules = [ ./hosts/omen15/omen15.nix ];
        };
        rpi4 = lib.nixosSystem {
          specialArgs = specialArgsForAll;
          modules = [ ./hosts/rpi4/rpi4.nix ];
        };
      };
    };
}
