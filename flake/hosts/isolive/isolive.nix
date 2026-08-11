# nix build '.#packages.x86_64-linux.iso-installer'
{
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

  # 图形安装器默认开启 ZFS 支持，但 zfs-kernel 模块常跟不上最新内核，标记
  # meta.broken 后会导致构建报错。装机 ISO 用不到 ZFS，直接关掉。
  boot.supportedFilesystems.zfs = false;

  # 禁用一些服务以简化ISO
  services.smartd.enable = false;

  networking.networkmanager.enable = true;

  environment.systemPackages = [
    # === 🛠️ 分区与文件系统工具 ===
    pkgs.testdisk
    pkgs.exfatprogs
    pkgs.ddrescue
    pkgs.gparted
    pkgs.parted
    pkgs.cryptsetup
    pkgs.dosfstools
    pkgs.ntfsprogs
    pkgs.btrfs-progs
    pkgs.xfsprogs
    pkgs.e2fsprogs

    # === 🔧 Windows急救工具 ===
    pkgs.chntpw
    pkgs.ntfs3g
    pkgs.wimlib

    # === 🖥️ EFI/引导修复工具 ===
    pkgs.efibootmgr
    pkgs.os-prober
    pkgs.grub2_efi

    # === 🔍 系统诊断工具 ===
    pkgs.memtest86plus
    pkgs.smartmontools
    pkgs.lshw
    pkgs.hwinfo
    pkgs.pciutils
    pkgs.usbutils
    pkgs.inxi
    pkgs.dmidecode
    pkgs.lsof

    # === Nix 安装工具 ===
    pkgs.nixos-install-tools
    pkgs.nixos-generators

    # === 图形工具 ===
    pkgs.librewolf
    pkgs.wezterm

    # sudo → doas compatibility shim
    pkgs.doas-sudo-shim
  ];

  # === 安全配置调整 ===
  services.openssh.settings = {
    PasswordAuthentication = true;
    PermitRootLogin = "yes";
  };

  # 允许无密码doas（安装时方便）
  security = {
    sudo-rs.enable = false;
    sudo.enable = false;
    doas = {
      enable = true;
      extraRules = [
        {
          groups = [ "wheel" ];
          noPass = true;
          keepEnv = true;
        }
      ];
    };
  };

  # 基础防火墙配置
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

}
