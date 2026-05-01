{ config, pkgs, ... }:
{
  hardware.amdgpu.overdrive.enable = true;
  hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr.icd ];
  hardware.graphics.extraPackages32 = [ pkgs.rocmPackages.clr.icd ];
  # AMD GPU control (hardware-specific)
  services.lact.enable = true;
}
