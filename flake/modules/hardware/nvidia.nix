{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.nvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU support";

    variant = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "open"
        "nouveau"
      ];
      default = "open";
      description = ''
        - nvidia: Official closed-source kernel module + userspace
        - open: Open-source kernel module (nvidia-open) + proprietary userspace
        - nouveau: Fully open-source reverse-engineered driver
      '';
    };

    amdgpuBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:7@0:0:0";
      description = "Bus ID for the AMD iGPU (lspci | grep VGA, format PCI:bus:dev:func)";
    };

    nvidiaBusId = lib.mkOption {
      type = lib.types.str;
      default = "PCI:1@0:0:0";
      description = "Bus ID for the NVIDIA dGPU (lspci | grep NVIDIA)";
    };
  };

  config = lib.mkIf config.modules.nvidia.enable {
    services.xserver.videoDrivers =
      if config.modules.nvidia.variant == "nouveau" then
        [
          "amdgpu"
          "nouveau"
        ]
      else
        [
          "amdgpu"
          "nvidia"
        ];

    boot.kernelParams =
      if config.modules.nvidia.variant == "nouveau" then
        [
          "nouveau.modeset=1"
          "nouveau.config=NvGspRm=1"
          "nouveau.config=NvBoost=2"
        ]
      else
        [
          "nvidia_drm.modeset=1"
          "nvidia_drm.fbdev=1"
          "nvidia_drm.fbdev_emulation=1"
        ];

    boot.blacklistedKernelModules =
      if config.modules.nvidia.variant == "nouveau" then
        [
          "nvidia"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidia_drm"
        ]
      else
        [ "nouveau" ];

    boot.extraModprobeConfig = lib.mkIf (config.modules.nvidia.variant != "nouveau") ''
      options nvidia-drm modeset=1
      options nvidia NVreg_EnableGpuFirmware=1

      # PreserveVideoMemoryAllocations:
      #   1 = keep GPU initialized across suspend/resume (preserves VRAM).
      #       Prevents dGPU from fully powering down -> ~9W extra idle drain.
      #       Use when actively running CUDA/ML/rendering workloads.
      #   0 = allow dGPU to fully suspend when no process uses it.
      #       Saves ~9W on battery. GPU contexts reinit after resume.
      #       Use for general desktop/battery-optimized use.
      options nvidia NVreg_PreserveVideoMemoryAllocations=0

      options nvidia NVreg_TemporaryFilePath=/var/tmp
      options nvidia NVreg_UsePageAttributeTable=1
      options nvidia NVreg_InitializeSystemMemoryAllocations=0
      options nvidia NVreg_DynamicPowerManagement=0x02
      options nvidia NVreg_RegistryDwords=RmEnableAggressiveVblank=1
    '';

    hardware.nvidia-container-toolkit.enable = lib.mkIf (config.modules.nvidia.variant != "nouveau") (
      lib.mkDefault true
    );

    hardware.nvidia = lib.mkIf (config.modules.nvidia.variant != "nouveau") {
      open = config.modules.nvidia.variant == "open";
      modesetting.enable = lib.mkDefault true;
      nvidiaPersistenced = lib.mkDefault false;
      videoAcceleration = lib.mkDefault true;
      dynamicBoost.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        finegrained = lib.mkDefault true; # conflict with sync
      };
      prime = {
        offload = {
          # mkOverride 900, not mkDefault: nixpkgs' own nvidia.nix sets this via
          # mkDefault false; same-priority mkDefault here would tie with it.
          enable = lib.mkOverride 900 true; # conflict with sync
          enableOffloadCmd = lib.mkOverride 900 true;
        };
        sync.enable = lib.mkDefault false;
        amdgpuBusId = config.modules.nvidia.amdgpuBusId;
        nvidiaBusId = config.modules.nvidia.nvidiaBusId;
      };
    };

    environment.systemPackages =
      [ ]
      ++ lib.optionals (config.modules.nvidia.variant != "nouveau") [
        pkgs.cudaPackages.cudatoolkit
        pkgs.nvidia-container-toolkit
      ];

    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
      extraPackages = lib.optionals (
        config.modules.nvidia.variant != "nouveau" && !config.modules.powersave.enable
      ) [ pkgs.nvidia-vaapi-driver ];
      extraPackages32 = lib.optionals (
        config.modules.nvidia.variant != "nouveau" && !config.modules.powersave.enable
      ) [ pkgs.nvidia-vaapi-driver ];
    };
  };
}
