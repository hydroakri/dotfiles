{
  description = "Standalone home-manager config for CLI tooling (portable to non-NixOS distros)";

  # bootstrap on a fresh machine that only has Nix:
  #   mkdir -p ~/.config/nix
  #   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  #   nix shell nixpkgs#git nixpkgs#chezmoi -c chezmoi init --apply https://github.com/hydroakri/dotfiles
  #   echo "trusted-users = root droid" | sudo tee -a /etc/nix/nix.conf
  #   sudo systemctl restart nix-daemon
  #   nix run home-manager/master -- switch --flake ~/.config/home-manager#$USER --impure
  #   nh home switch -- --impure   # note the trailing --, not a leading flag
  #
  # make the HM zsh your login shell (skip on NixOS — users.users.<name>.shell
  # already owns this declaratively; doing it here too would just fight it):
  #   ZSH_PATH="$HOME/.nix-profile/bin/zsh"
  #   grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
  #   chsh -s "$ZSH_PATH"
  inputs = {
    nixos-flake.url = "github:hydroakri/dotfiles?dir=flake";
    nixpkgs.follows = "nixos-flake/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nix-index-database,
      ...
    }:
    let
      pkgs = import nixpkgs {
        system = builtins.currentSystem;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations.${builtins.getEnv "USER"} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          nix-index-database.homeModules.nix-index
          ./home.nix
        ];
      };
    };
}
