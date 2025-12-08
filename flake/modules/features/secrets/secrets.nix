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
    # XXX: 强状态依赖 - SSH主机密钥必须存在，备份/迁移/全新安装时必须先恢复SSH密钥
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      doh_stamp = {};
      email = {};
    };
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