{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst";
    unstable.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
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
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
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
      # Do not override its nixpkgs input, otherwise there can be mismatch between patches and kernel version
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    owly = {
      url = "github:t4t5/owly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    trivalent-nix = {
      url = "github:hydroakri/trivalent-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-github-actions,
      treefmt-nix,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      # Make inputs available to all modules
      specialArgsForAll = { inherit inputs; };

      mkHost =
        {
          path,
          system ? null,
        }:
        lib.nixosSystem (
          {
            specialArgs = specialArgsForAll;
            modules = [ path ];
          }
          // lib.optionalAttrs (system != null) { inherit system; }
        );

      # Each host's system closure, keyed by system then hostname —
      # the shape nix-github-actions needs to derive a build matrix.
      hostToplevels = lib.foldl' lib.recursiveUpdate { } (
        lib.mapAttrsToList (hostname: cfg: {
          ${cfg.config.nixpkgs.hostPlatform.system}.${hostname} = cfg.config.system.build.toplevel;
        }) self.nixosConfigurations
      );

      # Systems covered by `nix fmt` / `nix flake check`'s formatting check.
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            statix.enable = true;
            deadnix.enable = true;
          };
        }
      );
    in
    {
      nixosConfigurations = {
        omen15 = mkHost { path = ./hosts/omen15/omen15.nix; };
        rpi4-side-gateway = mkHost { path = ./hosts/rpi4/rpi4-side-gateway.nix; };
        rpi4-switch = mkHost { path = ./hosts/rpi4/rpi4-switch.nix; };
        oci = mkHost { path = ./hosts/oci/oci.nix; };
      };

      packages = {
        x86_64-linux = {
          # isolive.nix imports the graphical calamares ISO module directly,
          # so `config.system.build.isoImage` is already available natively.
          iso-installer =
            (mkHost {
              system = "x86_64-linux";
              path = ./hosts/isolive/isolive.nix;
            }).config.system.build.isoImage;
        };
        aarch64-linux = {
          # rpi-image.nix imports the sd-image-aarch64 module directly,
          # so `config.system.build.sdImage` is already available natively.
          rpi-image =
            (mkHost {
              system = "aarch64-linux";
              path = ./hosts/rpi-image/rpi-image.nix;
            }).config.system.build.sdImage;
        };
      };

      nixosModules =
        lib.mapAttrs
          (name: path: {
            _class = "nixos";
            _file = "${self.outPath}/flake.nix#nixosModules.${name}";
            imports = [ path ];
          })
          {
            # Base profiles (pick one per host)
            core = ./modules/core.nix;
            desktop = ./modules/desktop.nix;
            server = ./modules/server.nix;
            # Feature modules (opt-in)
            performance = ./modules/features/performance.nix;
            security = ./modules/features/security.nix;
            privacy = ./modules/features/privacy.nix;
            powersave = ./modules/features/powersave.nix;
            gaming = ./modules/features/gaming.nix;
            preservation = ./modules/features/preservation.nix;
            utils = ./modules/features/utils.nix;
            virtualisation = ./modules/features/virtualisation.nix;
            networking-router = ./modules/features/networking/router.nix;
            networking-sqm = ./modules/features/networking/sqm.nix;
            networking-tuning = ./modules/features/networking/tuning.nix;
            networking-warp = ./modules/features/networking/warp.nix;
            # Hardware / filesystem helpers
            hardware-amd = ./modules/hardware/amd.nix;
            hardware-nvidia = ./modules/hardware/nvidia.nix;
            filesystem-btrfs = ./modules/filesystems/btrfs.nix;
          }
        // {
          default = self.nixosModules.core;
        };

      # Drives the CI matrix: `nix eval --json .#githubActions.matrix`
      githubActions = nix-github-actions.lib.mkGithubMatrix {
        checks = hostToplevels;
      };

      # `nix fmt` — nixfmt + statix + deadnix, config in ./treefmt.nix
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Picked up by `nix flake check` automatically
      checks = forAllSystems (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });
    };
}
