{ config, pkgs, ... }: {
  hardware.amdgpu.overdrive.enable = true;
  hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr.icd ];
  hardware.graphics.extraPackages32 = with pkgs; [ rocmPackages.clr.icd ];
  # AMD GPU control (hardware-specific)
  services.lact.enable = true;
}

