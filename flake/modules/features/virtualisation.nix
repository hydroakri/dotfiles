{ config, pkgs, lib, ... }:
{
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
  # 仅在非 aarch64 系统上启用 aarch64 模拟
  boot.binfmt.emulatedSystems = lib.subtractLists [ pkgs.stdenv.hostPlatform.system ] [
  "aarch64-linux"
  "x86_64-linux"
  ];
  environment.systemPackages = [ pkgs.distrobox ];

}
