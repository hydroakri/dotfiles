{ pkgs, ... }:
{
  home.packages = [
    pkgs.fastfetch
    pkgs.opencode
    pkgs.claude-code
    pkgs.cliamp
  ];
}
