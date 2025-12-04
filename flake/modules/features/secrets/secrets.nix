{ config, lib, pkgs, ... }:
let zeroTrust = "ZEROTRUST";
in {
  options.modules.secrets.zeroTrust = lib.mkOption {
    type = lib.types.str;
    default = zeroTrust;
    description = "ZeroTrust stamp placeholder for dnscrypt-proxy";
  };

  config.sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.doh_stamp = { };
    templates."dnscrypt-proxy.toml" = {
      mode = "0444";
      content = builtins.replaceStrings [ zeroTrust ]
        [ config.sops.placeholder.doh_stamp ] (builtins.readFile
          (pkgs.runCommand "to-toml" { nativeBuildInputs = [ pkgs.yj ]; } ''
            echo '${
              builtins.toJSON config.services.dnscrypt-proxy.settings
            }' | yj -jt > $out
          ''));
    };
  };
}
