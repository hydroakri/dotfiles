{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.kernelModules = [ "ntsync" ];
  hardware.steam-hardware.enable = lib.mkDefault true;
  hardware.uinput.enable = lib.mkDefault true;
  users.users.${config.mainUser}.extraGroups = [ "uinput" ];
  environment.systemPackages = [
    pkgs.yad # steamtinkerlaunch dependency
    pkgs.ethtool
  ];

  programs.gamescope = {
    enable = lib.mkDefault true;
    capSysNice = lib.mkDefault true;
  };

  programs.steam = {
    enable = lib.mkDefault false;
    remotePlay.openFirewall = lib.mkDefault true;
    dedicatedServer.openFirewall = lib.mkDefault true;
    localNetworkGameTransfers.openFirewall = lib.mkDefault true;
    gamescopeSession.enable = lib.mkDefault true;
    extraCompatPackages = [ pkgs.steamtinkerlaunch ];
  };

  programs.gamemode.enable = lib.mkDefault true;
  environment.sessionVariables.WINEFSYNC = lib.mkDefault "1";
  users.groups.gamemode = { };

  services.scx = {
    enable = lib.mkOverride 900 true;
    scheduler = lib.mkOverride 900 "scx_lavd";
    extraArgs = [ "--autopower" ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      5222
      25565
      27015
      27036
      27037
      27040
      53317
    ];
    allowedUDPPorts = [
      7777
      27015
      27031
      27036
      53317
    ];
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
