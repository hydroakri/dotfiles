{ pkgs, inputs, ... }:
{
  home.packages = [
    pkgs.fastfetch
    inputs.herdr-nix.packages.${pkgs.system}.default
    pkgs.opencode
    pkgs.claude-code
    pkgs.cliamp
  ];
}
