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
      nixpkgs.overlays = [
        (_final: prev: {
          libdisplay-info_0_3 = prev.libdisplay-info.overrideAttrs (
            finalAttrs: _: {
              version = "0.3.0";
              src = prev.fetchFromGitLab {
                domain = "gitlab.freedesktop.org";
                owner = "emersion";
                repo = "libdisplay-info";
                rev = finalAttrs.version;
                sha256 = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
              };
            }
          );
        })
      ];

      hardware.amdgpu.overdrive.enable = lib.mkDefault true;
      services.lact = {
        enable = lib.mkDefault true;
        package = pkgs.lact.override { libdisplay-info = pkgs.libdisplay-info_0_3; };
      };
    }
  ];
}
