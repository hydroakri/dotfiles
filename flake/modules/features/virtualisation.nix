{ config, pkgs, ... }: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--filter" "label!=manager=distrobox" ];
    };
  };
  environment.systemPackages = with pkgs; [ distrobox ];

}
