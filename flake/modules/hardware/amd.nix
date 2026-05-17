{ config, lib, pkgs, ... }:
with lib;
{
  options.modules.amd = {
    rocm = mkEnableOption "ROCm OpenCL support for AMD GPUs (required for some video editing and ML workloads)";
  };

  config = mkMerge [
    (mkIf config.modules.amd.rocm {
      hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr.icd ];
      hardware.graphics.extraPackages32 = [ pkgs.rocmPackages.clr.icd ];
    })
    {
      hardware.amdgpu.overdrive.enable = true;
      services.lact.enable = true;
    }
  ];
}
