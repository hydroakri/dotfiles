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
    ../../modules/features/networking/proxy-nodes.nix
    ../../modules/features/preservation.nix
    ../../modules/features/secrets/secrets.nix
    ../../modules/features/security.nix
    ../../modules/features/privacy.nix
    ../../modules/features/utils.nix
    ../../modules/features/virtualisation.nix
    ../../modules/features/gaming.nix
    ../../modules/features/agent.nix
    ../../modules/features/networking/warp.nix

    # Filesystem modules
    ../../modules/filesystems/btrfs.nix

    # Hardware-specific modules
    ../../modules/hardware/amd.nix
    ../../modules/hardware/nvidia.nix

    # External modules
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    inputs.owly.nixosModules.default
  ];
  services.owly.enable = true;
  mainUser = "hydroakri";
  sops.secrets = {
    email = { };
    password.neededForUsers = true;
  };
  users.users.${config.mainUser}.hashedPasswordFile = config.sops.secrets.password.path;

  modules = {
    core = {
      extraSubstituters = [
        "https://cache.hydroakri.cc/cachix"
        "https://attic.xuyh0120.win/lantian"
      ];
      extraTrustedPublicKeys = [
        "cachix:RTT3Lx/HwP7OQwsaF6HpidQZvmpbu6xxa/Bc9CCp8zI="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      ];
    };
    security = {
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAw4ah1WaneMXXpgSwKQ43GLuLDg+7FQOzg6+Sw0JgqIAAAABHNzaDo= nitrokey"
      ];
      u2fMappings = "hydroakri:owBYeHN6l0L7NTWQJ+iHn18m8CiXzAy2JggKsESzbEXtAXMcJ5fSTxANHwCFUtm7fJPta9SPXOZaHNr3pmIng2leqP7NyycxJ/wIhv03oJgNxgAWi4fNNtw3Y+uCP2hnjZ3VZay4oh2NkmXmSAm/164uQOi38OAbtHvFYgFM1EeLOtkZweoI3DmIAlC6TaQ0fkWthUGYVxTadelu,WBJenK89qfrOaCmV+dB+WVd2rBL+GzGp28r6X/NgRhLnKXvz2u8BEtUZ9ERbmfyXYkN9/pwi3llmoboiail86A==,es256,+presence\n";
      # hash 绑定设备描述符；不含 via-port/parent-hash，换口或经 hub 仍可用
      usbguardRules = ''
        allow id 20a0:42b2 serial "" name "Nitrokey 3" hash "kSortoF1dGu28PvJ1LQ1E4Wz0jsZI/PC8gMxXpRmV3Y="
      '';
    };
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
          rps_cpus = "fffe";
        };
        wlo1 = {
          rps_cpus = "fffe";
        };
      };
    };
    proxy = {
      enable = true;
      singbox = {
        enable = true;
        tun = true;
      };
      tor.enable = true;
    };
    powersave = {
      enable = true;
      wakeOnLan.interfaces = [
        "wlo1"
        "eno1"
      ];
    };
    preservation.enable = true;
  };

  # Boot menu entry (limine) that fully cuts power to the nvidia dGPU.
  # No nvidia/nouveau driver is bound, so generic PCI runtime PM + ACPI _PR3
  # puts the card into D3cold (near-zero power draw) instead of just idling.
  specialisation.nvidia-off.configuration = {
    modules.nvidia.enable = lib.mkForce false;
    boot.blacklistedKernelModules = [
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
      "nouveau"
    ];
    services.xserver.videoDrivers = lib.mkForce [ "amdgpu" ];
    # nvidiaBusId "PCI:1@0:0:0" -> sysfs 0000:01:00.0
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:01:00.0", TEST=="power/control", ATTR{power/control}="auto"
    '';
  };
  # SSH signing key for git commit verification
  sops.templates."ssh/allowed_signers" = {
    content = ''
      # 格式: <email> <public_key>
      24475059+hydroakri@users.noreply.github.com sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIORKNKURAriDLXiBpCKeuc3aBcIkQJy32I+sOpwMaWUmAAAABHNzaDo= hydroakri
      24475059+hydroakri@users.noreply.github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE ${config.sops.placeholder.email}
    '';
    mode = "0444";
  };
  programs.git.config."gpg \"ssh\"".allowedSignersFile =
    config.sops.templates."ssh/allowed_signers".path;

  boot = {
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;
    # kernelPackages = pkgs.linuxPackages_xanmod_stable;
    kernelParams = [ "amd_pstate=active" ];
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
        (config.boot.kernelPackages.zenpower.overrideAttrs (
          old:
          {
            # zenpower5's multi-file refactor dropped the <asm/cpuid/api.h> include
            # that cpuid_ecx needs on kernel >=7.2; patch every .c file that calls it.
            postPatch =
              (old.postPatch or "")
              + ''
                for f in *.c; do
                  grep -q 'cpuid_ecx' "$f" && sed -i '/#include <linux\/pci.h>/a\
                #if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 2, 0)\
                #include <asm/cpuid/api.h>\
                #endif' "$f"
                done
              ''
              + lib.optionalString isClang ''
                sed -i '/-Wimplicit-fallthrough=3/d' Makefile
              '';
          }
          // lib.optionalAttrs isClang {
            makeFlags = (old.makeFlags or [ ]) ++ [
              "CC=${kernel.stdenv.cc.cc}/bin/clang"
              "LLVM=1"
              "LLVM_IAS=1"
            ];
          }
        ))
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
        /macOS (OpenCore)
            protocol: efi
            path: guid(a2410551-d3da-468a-a70d-2f9406029105):/EFI/BOOT/BOOTx64.efi
      '';
    };
  };
  environment.etc."nixos/nbfc.json".text = builtins.toJSON {
    SelectedConfigId = "HP OMEN Laptop 15-en0xxx";
  };
  # Enable DHCP by default for network interfaces
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager = {
    wifi.backend = "wpa_supplicant";
  };
  systemd.services.nbfc_service = {
    # nbfc-linux fancontrol
    enable = true;
    description = "NoteBook FanControl service";
    path = [ pkgs.kmod ];
    script = "${pkgs.nbfc-linux}/bin/nbfc_service -c /etc/nixos/nbfc.json";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      NoNewPrivileges = true;
      ProtectHome = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectControlGroups = true;
      LockPersonality = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      SystemCallArchitectures = "native";
    };
  };
  environment.systemPackages = [
    pkgs.nbfc-linux
    # pkgs.winboat
  ];
  modules.warp.enable = true;
  services.sunshine = {
    enable = false;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  services.udev.extraRules = ''
    # ArbotiX-M robocontroller (FT232R USB-UART bridge) -> /dev/ttyUSB*
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0666"
    # Intel RealSense D435 -- raw USB device plus its video4linux streams
    SUBSYSTEM=="usb", ATTR{idVendor}=="8086", ATTR{idProduct}=="0b07", MODE="0666"
    KERNEL=="video[0-9]*", ATTRS{idVendor}=="8086", ATTRS{idProduct}=="0b07", MODE="0666"
  '';

  system.stateVersion = "25.11";
}
