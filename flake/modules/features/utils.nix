{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    ## GPU / display tools
    nvtopPackages.full
    virtualglLib
    vulkan-tools
    libva-utils
    vdpauinfo
    read-edid
    clinfo
  ];
  fonts.fontDir = {
    enable = true;
    decompressFonts = true;
  };
}
