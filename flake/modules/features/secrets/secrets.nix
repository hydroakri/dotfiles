{ config, lib, pkgs, ... }: {

  config.sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    # XXX: 强状态依赖 - SSH主机密钥必须存在，备份/迁移/全新安装时必须先恢复SSH密钥
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = { email = { }; };
  };
}

