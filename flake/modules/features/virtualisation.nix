{ config, pkgs, ... }: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--filter" "label!=manager=distrobox" ];
    };
  };
  # 启用 QEMU 模拟，让 x86 机器可以编译和运行 ARM 程序
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  environment.systemPackages = with pkgs; [ distrobox ];

}
