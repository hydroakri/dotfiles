{ config, lib, pkgs, ... }: {
  options.modules.secrets.zeroTrust = lib.mkOption {
    type = lib.types.str;
    default = "ZEROTRUST";
    description = "ZeroTrust stamp placeholder for dnscrypt-proxy";
  };

  config.sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    # XXX: 强状态依赖 - SSH主机密钥必须存在，备份/迁移/全新安装时必须先恢复SSH密钥
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      doh_stamp = { };
      email = { };
      sing-box-outbounds = { };
    };

    templates."dnscrypt-proxy.toml" = {
      mode = "0444";
      content = builtins.replaceStrings [ "ZEROTRUST" ]
        [ config.sops.placeholder.doh_stamp ] (builtins.readFile
          (pkgs.runCommand "to-toml" { nativeBuildInputs = [ pkgs.yj ]; } ''
            echo '${
              builtins.toJSON config.services.dnscrypt-proxy.settings
            }' | yj -jt > $out
          ''));
    };

    templates."config.json" = {
      owner = "sing-box"; # 确保 sing-box 进程有权读取
      restartUnits = [ "sing-box.service" ]; # 模板变化时重启服务
      content = builtins.replaceStrings [ ''"OUTBOUNDS_PLACEHOLDER"'' ]
        [ config.sops.placeholder."sing-box-outbounds" ]
        (builtins.toJSON config.services.sing-box.settings);
    };

  };
}

