# Custom hardware configuration for HP Omen 15
# sudo nixos-generate-config --show-hardware-config > ./hardware-configuration.nix
# This file contains manual modifications and optimizations to the auto-generated hardware config
{ config, lib, pkgs, ... }:

{
  # Add additional kernel modules for better hardware support
  boot.initrd.availableKernelModules = lib.mkAfter [
    "usb_storage"
    "sd_mod"
  ];

  # Override filesystem mount options with performance optimizations
  fileSystems."/" = {
    options = lib.mkForce [
      "subvol=@"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=120"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  fileSystems."/nix" = {
    options = lib.mkForce [
      "subvol=@nix"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=120"
      "compress=zstd:3"
      "discard=async"
      "autodefrag"
    ];
  };

  fileSystems."/home" = {
    options = lib.mkForce [
      "subvol=@home"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=120"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  fileSystems."/var/log" = {
    options = lib.mkForce [
      "subvol=@log"
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=120"
      "compress=zstd:3"
      "discard=async"
    ];
  };

  # Override steam-linux filesystem to use label instead of UUID
  fileSystems."/steam-linux" = {
    device = lib.mkForce "LABEL=steam-linux";
    options = lib.mkForce [
      "rw"
      "relatime"
      "ssd"
      "space_cache=v2"
      "noatime"
      "nodiratime"
      "commit=120"
      "compress=zstd:3"
      "discard=async"
      "autodefrag"
    ];
  };

  # Enable DHCP by default for network interfaces
  networking.useDHCP = lib.mkDefault true;
}
