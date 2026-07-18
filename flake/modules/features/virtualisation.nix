{
  config,
  pkgs,
  lib,
  ...
}:
{
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

  # KVM/QEMU + libvirtd 完整虚拟化栈，仅在 amd64 (x86_64) 主机上启用
  virtualisation.libvirtd = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") true;
  users.users.${config.mainUser}.extraGroups = lib.mkIf (
    pkgs.stdenv.hostPlatform.system == "x86_64-linux"
  ) [ "libvirtd" ];

  environment.systemPackages = [ pkgs.distrobox ];

}
