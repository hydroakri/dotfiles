{ config, lib, pkgs, ... }: {
  specialisation = {
    nvidia-variant.configuration = {
      system.nixos.tags = [ "nvidia" ];
      services.xserver.videoDrivers = [ "nvidia" ];
      boot.kernelParams = [ "nvidia_drm.modeset=1" "nvidia_drm.fbdev=1" ];
      # Early KMS
      boot.initrd.kernelModules =
        [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
      boot.extraModprobeConfig = ''
        options nvidia-drm modeset=1
        options nvidia NVreg_EnableGpuFirmware=1
        options nvidia NVreg_PreserveVideoMemoryAllocations=1
        options nvidia NVreg_TemporaryFilePath=/var/tmp
      '';
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
      environment.systemPackages = with pkgs; [ cudaPackages.cudatoolkit ];
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [ nvidia-vaapi-driver ];
        extraPackages32 = with pkgs; [ nvidia-vaapi-driver ];
      };
    };
  };
}
