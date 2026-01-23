{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    yad # steamtinkerlaunch dependency
    steam-devices-udev-rules
    ethtool
  ];

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.steam = {
    enable = false;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [ steamtinkerlaunch ];
  };

  programs.gamemode.enable = true;
  users.groups.gamemode = { };

  # Ananicy - process priority optimization for gaming
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
  services.scx = lib.mkForce {
    enable = true;
    scheduler = "scx_lavd";
    extraArgs = [ "--autopower" ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 5222 25565 27015 27036 27037 27040 53317 ];
    allowedUDPPorts = [ 7777 27015 27031 27036 53317 ];
    allowedUDPPortRanges = [
      {
        from = 27031;
        to = 27036;
      }
      {
        from = 8000;
        to = 8010;
      }
    ];
  };
}
