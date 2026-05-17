{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.amd.rocm = lib.mkEnableOption "ROCm OpenCL support for AMD GPUs (required for some video editing and ML workloads)";

  config = lib.mkMerge [
    (lib.mkIf config.modules.amd.rocm {
      hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr.icd ];
      hardware.graphics.extraPackages32 = [ pkgs.rocmPackages.clr.icd ];
    })
    {
      hardware.amdgpu.overdrive.enable = true;
      services.lact.enable = true;
    }
  ];
}
