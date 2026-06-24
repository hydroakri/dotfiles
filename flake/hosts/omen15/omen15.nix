# nh os switch -H omen15 ./
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  networking.hostName = "omen15";
  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
  ];
  imports = [
    # Hardware configuration
    ./disko.nix

    # Core system modules
    ../../modules/core.nix
    ../../modules/desktop.nix

    # Feature modules
    ../../modules/features/performance.nix
    ../../modules/features/powersave.nix
    ../../modules/features/networking/proxy.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix
    ../../modules/features/utils.nix
    ../../modules/features/virtualisation.nix
    ../../modules/features/gaming.nix

    # Filesystem modules
    ../../modules/filesystems/btrfs.nix

    # Hardware-specific modules
    ../../modules/hardware/amd.nix
    ../../modules/hardware/nvidia.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
  ];
  modules = {
    performance.vendor = "amd";
    nvidia = {
      enable = true;
      variant = "open";
      amdgpuBusId = "PCI:7@0:0:0";
      nvidiaBusId = "PCI:1@0:0:0";
    };
    networking.sqm = {
      enable = true;
      wanInterface = "wlo1";
      lanInterface = "wlo1";
    };
    networking.sysfsTuning = {
      enable = true;
      interfaces = {
        eno1 = {
          rps_cpus = "fe";
          xps_cpus = "fe";
        };
        wlo1 = {
          rps_cpus = "fe";
          xps_cpus = "fe";
        };
      };
    };
    proxy = {
      enable = true;
      singbox.enable = true;
      singbox.tun = true;
      singbox.dns = true;
      singbox.endpoints = true;
      singbox.outbounds = true;
    };
    powersave = {
      enable = true;
      wakeOnLan.interfaces = [
        "wlo1"
        "eno1"
      ];
    };
    utils = {
      enable = true;
      enableGraphicTools = true;
      enableGlance = true;
      enableUptime = false;
    };
  };
  boot = {
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;
    # kernelPackages = pkgs.linuxPackages_xanmod_stable;
    kernelModules = [
      "zenpower"
      "kvm-amd"
    ];
    initrd.kernelModules = [ "amdgpu" ];
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "usbhid"
      "sdhci_pci"
      "usb_storage"
      "sd_mod"
    ];
    blacklistedKernelModules = [ "k10temp" ];
    extraModulePackages =
      let
        kernel = config.boot.kernelPackages.kernel;
        isClang = kernel.stdenv.cc.isClang or false;
      in
      [
        (
          if isClang then
            config.boot.kernelPackages.zenpower.overrideAttrs (old: {
              makeFlags = (old.makeFlags or [ ]) ++ [
                "CC=${kernel.stdenv.cc.cc}/bin/clang"
                "LLVM=1"
                "LLVM_IAS=1"
              ];
            })
          else
            config.boot.kernelPackages.zenpower
        )
      ];
    extraModprobeConfig = ''
      options snd_hda_intel power_save=1
    '';
    loader.efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    loader.limine = {
      enable = true;
      biosDevice = "nodev";
      efiSupport = true;
      maxGenerations = 5;
      secureBoot.enable = true;
      secureBoot.sbctl = pkgs.sbctl;
      extraConfig = ''
        timeout: no
      '';
      extraEntries = ''
        /Windows
            protocol: efi
            path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
      '';
    };
  };
  environment.etc."nixos/nbfc.json".text = builtins.toJSON {
    SelectedConfigId = "HP OMEN Laptop 15-en0xxx";
  };
  networking.networkmanager = {
    wifi.backend = "wpa_supplicant";
  };
  systemd.services.nbfc_service = {
    # nbfc-linux fancontrol
    enable = true;
    description = "NoteBook FanControl service";
    serviceConfig.Type = "simple";
    path = [ pkgs.kmod ];
    script = "${pkgs.nbfc-linux}/bin/nbfc_service -c /etc/nixos/nbfc.json";
    wantedBy = [ "multi-user.target" ];
  };
  environment.systemPackages = [
    pkgs.nbfc-linux
  ];
  # Application-specific programs (host-specific)
  # systemd.services.dae.wantedBy = lib.mkForce [ ]; # prevent dae auto start
  # systemd.services.dnscrypt-proxy.wantedBy = lib.mkForce [ ];
  # services.cloudflare-warp.enable = true;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  # ============================================================================
  # Custom Hardware Configuration
  # ============================================================================
  # Enable DHCP by default for network interfaces
  networking.useDHCP = lib.mkDefault true;

  system.stateVersion = "25.11";
}
