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
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "github:nix-community/preservation";
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
          # isolive.nix imports the graphical calamares ISO module directly,
          # so `config.system.build.isoImage` is already available natively.
          iso-installer =
            (lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = specialArgsForAll;
              modules = [ ./hosts/isolive/isolive.nix ];
            }).config.system.build.isoImage;
        };
        aarch64-linux = {
          # rpi-image.nix imports the sd-image-aarch64 module directly,
          # so `config.system.build.sdImage` is already available natively.
          rpi-image =
            (lib.nixosSystem {
              system = "aarch64-linux";
              specialArgs = specialArgsForAll;
              modules = [ ./hosts/rpi-image/rpi-image.nix ];
            }).config.system.build.sdImage;
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
        privacy = ./modules/features/privacy.nix;
        powersave = ./modules/features/powersave.nix;
        gaming = ./modules/features/gaming.nix;
        preservation = ./modules/features/preservation.nix;
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
