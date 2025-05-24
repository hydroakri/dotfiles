{
  description = "A universal NixOS + Home Manager flake configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      # Common NixOS configuration
      commonNixOSConfig = {
        # Define common services, packages, and settings here
        environment.systemPackages = with pkgs; [ vim git curl ];
        services.openssh.enable = true;
        # More common settings...
      };

      # Host-specific overrides
      hosts = {
        "hostA" = {
          networking.hostName = "hostA";
          # hostA-specific packages or services
          environment.systemPackages = with pkgs; [ htop ];
        };
        "hostB" = {
          networking.hostName = "hostB";
          # hostB-specific adjustments
          services.httpd.enable = true;
          services.httpd.adminAddr = "admin@example.com";
        };
      };

      # User-specific Home Manager configuration
      users = {
        "alice" = {
          home.username = "alice";
          home.homeDirectory = "/home/alice";
          home.packages = with pkgs; [ zsh bat ];
          programs.zsh.enable = true;
          # More alice-specific home-manager settings
        };
        "bob" = {
          home.username = "bob";
          home.homeDirectory = "/home/bob";
          home.packages = with pkgs; [ emacs tmux ];
          programs.bash.enable = true;
        };
      };
    in
    {
      # NixOS system configurations by hostname
      nixosConfigurations = lib.mapAttrs (hostName: hostOverrides:
        nixpkgs.lib.nixosSystem {
          system = system;
          modules = [ home-manager.nixosModules.home-manager ];
          configuration = lib.recursiveUpdate commonNixOSConfig hostOverrides;
        }
      ) hosts;

      # Home Manager configurations by username
      homeManagerConfigurations = lib.mapAttrs (userName: userConfig:
        home-manager.lib.homeManagerConfiguration {
          inherit system;
          modules = [ userConfig ];
        }
      ) users;
    }
}
