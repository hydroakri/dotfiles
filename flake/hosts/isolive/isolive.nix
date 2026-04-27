# nix build '.#packages.x86_64-linux.iso-installer'
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    # 官方 ISO 基础模块
    "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix"

    # 复用核心模块，但调整安全配置
    ../../modules/core.nix
    ../../modules/desktop.nix
  ];

  # === 基础系统配置 ===
  networking.hostName = "nixos-installer";

  # 禁用一些服务以简化ISO
  services.smartd.enable = lib.mkForce false;

  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    # === 🛠️ 分区与文件系统工具 ===
    testdisk
    exfatprogs
    ddrescue
    gparted
    parted
    cryptsetup
    dosfstools
    ntfsprogs
    btrfs-progs
    xfsprogs
    e2fsprogs

    # === 🔧 Windows急救工具 ===
    chntpw
    ntfs3g
    wimlib

    # === 🖥️ EFI/引导修复工具 ===
    efibootmgr
    os-prober
    grub2_efi

    # === 🔍 系统诊断工具 ===
    memtest86plus
    smartmontools
    lshw
    hwinfo
    pciutils
    usbutils
    inxi
    dmidecode
    lsof

    # === Nix 安装工具 ===
    nixos-install-tools
    nixos-generators

    # === 图形工具 ===
    librewolf
    wezterm
  ];

  # === 安全配置调整 ===
  services.openssh.settings = {
    PasswordAuthentication = true;
    PermitRootLogin = "yes";
  };

  # 允许无密码sudo（安装时方便）
  security = {
    sudo-rs.enable = true;
    sudo-rs.wheelNeedsPassword = false;
    sudo.enable = false;
  };

  # 基础防火墙配置
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

}
