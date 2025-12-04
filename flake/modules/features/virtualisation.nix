{ config, pkgs, ... }: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };
  environment.systemPackages = with pkgs; [ distrobox ];

}
