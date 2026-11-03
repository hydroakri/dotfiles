{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.modules.warp = {
    enable = lib.mkEnableOption "Cloudflare WARP client with sops-provided MDM policy";
    fullTunnel = lib.mkEnableOption "forcing service_mode=warp (global tunnel) regardless of the secret's mode";
  };

  config = lib.mkIf config.modules.warp.enable {
    services.cloudflare-warp.enable = true;
    # sops-nix places secrets as symlinks; warp-svc opens its MDM policy file
    # with O_NOFOLLOW, so a symlinked mdm.xml fails with ELOOP and the client
    # never registers. Copy the secret into a real file before each start.
    sops.secrets."warp_mdm" = {
      sopsFile = ../secrets/secrets.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "cloudflare-warp.service" ];
    };
    systemd.services.cloudflare-warp.preStart = ''
      install -m 0400 -o root -g root ${config.sops.secrets.warp_mdm.path} /var/lib/cloudflare-warp/mdm.xml.tmp
      ${lib.optionalString config.modules.warp.fullTunnel ''
        ${pkgs.perl}/bin/perl -0pi -e 's{<key>service_mode</key>\s*<string>[^<]*</string>\s*}{}g; s{(.*)</dict>}{$1<key>service_mode</key>\n<string>warp</string>\n</dict>}s' /var/lib/cloudflare-warp/mdm.xml.tmp
      ''}
      mv -f /var/lib/cloudflare-warp/mdm.xml.tmp /var/lib/cloudflare-warp/mdm.xml
    '';

    # warp-svc's DNS proxy binds 127.0.2.2/3:53; a wildcard :53 listener makes it fail with "port 53 in use".
    services.unbound.settings.server.interface = lib.mkIf config.modules.warp.fullTunnel [
      "127.0.0.1"
      "::1"
    ];
  };
}
