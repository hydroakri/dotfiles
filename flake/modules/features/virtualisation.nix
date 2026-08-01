{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.modules.virtualisation.libvirtd.enable = lib.mkEnableOption "KVM/QEMU + libvirtd";

  config = {
    virtualisation.podman = {
      enable = lib.mkDefault true;
      dockerCompat = lib.mkDefault true;
    };
    # 仅在非 aarch64 系统上启用 aarch64 模拟
    boot.binfmt.emulatedSystems =
      lib.subtractLists
        [ pkgs.stdenv.hostPlatform.system ]
        [
          "aarch64-linux"
          "x86_64-linux"
        ];

    # KVM/QEMU + libvirtd 完整虚拟化栈，仅在显式启用时开启
    virtualisation.libvirtd = lib.mkIf config.modules.virtualisation.libvirtd.enable {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };
    programs.virt-manager.enable = lib.mkIf config.modules.virtualisation.libvirtd.enable true;
    users.users.${config.mainUser}.extraGroups =
      lib.mkIf config.modules.virtualisation.libvirtd.enable
        [
          "libvirtd"
        ];

    environment.systemPackages = [ pkgs.distrobox ];
  };
}
