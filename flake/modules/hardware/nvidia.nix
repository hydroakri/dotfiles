{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.nvidia;
in
{
  options.modules.nvidia.enable = mkEnableOption "NVIDIA support";

  config = mkIf cfg.enable {
    system.nixos.tags = [ "nvidia" ];
    services.xserver.videoDrivers = [
      "amdgpu"
      "nvidia"
    ];
    boot.kernelParams = [
      "nvidia_drm.modeset=1"
      "nvidia_drm.fbdev=1"
    ];
    boot.blacklistedKernelModules = [ "nouveau" ];
    # boot.initrd.kernelModules =
    #  [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
    boot.extraModprobeConfig = ''
      options nvidia-drm modeset=1
      options nvidia NVreg_EnableGpuFirmware=1
      options nvidia NVreg_PreserveVideoMemoryAllocations=1
      options nvidia NVreg_TemporaryFilePath=/var/tmp
      options nvidia NVreg_UsePageAttributeTable=1
      options nvidia NVreg_InitializeSystemMemoryAllocations=0
      options nvidia NVreg_DynamicPowerManagement=0x02
      options nvidia NVreg_RegistryDwords=RmEnableAggressiveVblank=1
    '';
    hardware.nvidia-container-toolkit.enable = true;
    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      nvidiaPersistenced = false;
      videoAcceleration = true;
      dynamicBoost.enable = true;
      powerManagement = {
        enable = true;
        finegrained = true; # conflict with sync
      };
      prime = {
        offload = {
          enable = true; # conflict with sync
          enableOffloadCmd = true; # like `prime-run`
        };
        sync.enable = false;
        amdgpuBusId = "PCI:7@0:0:0";
        nvidiaBusId = "PCI:1@0:0:0";
      };
    };
    environment.systemPackages = [
      pkgs.cudaPackages.cudatoolkit
      pkgs.nvidia-container-toolkit
    ];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = [ pkgs.nvidia-vaapi-driver ];
      extraPackages32 = [ pkgs.nvidia-vaapi-driver ];
    };
  };
}
