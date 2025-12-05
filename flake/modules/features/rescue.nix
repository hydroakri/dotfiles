{ config, pkgs, lib, ... }: {
  # 1. 强制设定 Root 密码哈希 (兜底手段)
  # 使用命令 `mkpasswd -m sha-512` 生成，不要写明文
  # 或者使用能访问系统/etc/shadow中已知sha的密码
  # users.users.root.initialHashedPassword = "$6$.......";

  # 2. 强制将 SSH 公钥写入系统级配置 (不依赖 /home 或 sops)
  # 这样即使 /home 挂载失败，root 依然能通过 SSH 登录
  # users.users.root.openssh.authorizedKeys.keys = [
  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..." # 你的开发机公钥
  # ];

  # 3. 允许 Root SSH 登录 (仅限密钥)
  # 防止普通用户 sudo 配置错误导致无法提权
  services.openssh.settings.PermitRootLogin = "prohibit-password";

  # 4. 启用可变的 /etc/shadow
  # 允许你在紧急情况下用 `passwd` 命令临时改密码，而不必每次都重新构建
  users.mutableUsers = true;
}
