{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.modules.warp.enable = lib.mkEnableOption "Cloudflare WARP client with sops-provided MDM policy";

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
      mv -f /var/lib/cloudflare-warp/mdm.xml.tmp /var/lib/cloudflare-warp/mdm.xml
    '';
  };
}
