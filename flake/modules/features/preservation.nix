# tmpfs-on-root + preservation。机制和"通用"路径放这；主机专属数据放各主机自己的配置里。
#
# 边界条件：
# 1. inInitrd 条目必须用 bindmount（默认），不能用 symlink：symlink 不会像 mount unit
#    那样自动带上"先挂好持久化分区"的依赖，指向的会是空气。
# 2. 给已有数据的机器新增条目，要手动 rsync 一次旧数据过去，preservation 不会帮你搬。
{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.preservation.nixosModules.preservation ];

  options.modules.preservation = {
    enable = lib.mkEnableOption "tmpfs-on-root with preservation-based state persistence";

    persistentPath = lib.mkOption {
      type = lib.types.str;
      default = "/persistent";
      description = "承载 preservation.preserveAt 数据的持久化挂载点。";
    };
  };

  config = lib.mkIf config.modules.preservation.enable {
    boot.initrd.systemd.enable = lib.mkDefault true;

    # persistentPath 必须在 initrd 阶段就真实挂载好，否则 inInitrd 的 bind mount/symlink
    # 挂到的只是 tmpfiles 顺手建出的空占位文件（挂载本身不报错，只有内容是空的）
    fileSystems.${config.modules.preservation.persistentPath}.neededForBoot = true;

    # bind-mounted machine-id 直接挂载写回持久化存储；ConditionFirstBoot 语义在这不适用
    systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

    preservation.enable = lib.mkDefault true;

    # 通用路径：不管哪台主机，只要用这个模块、跑了对应服务就该持久化的东西。
    # 主机专属的（跟具体硬件型号绑定的）留在各主机自己的配置里，会跟这里自动合并。
    preservation.preserveAt.${config.modules.preservation.persistentPath} = {
      directories = [
        "/var/lib/nixos" # 声明式用户/组的 uid/gid 分配记录，没有会跟 /home 权限对不上
        "/var/lib/NetworkManager"
        "/etc/NetworkManager/system-connections"
        "/var/lib/unbound"
        {
          # chronyd 没有 StateDirectory= 自我校正,默认 0755 root:root 会卡住写权限。
          directory = "/var/lib/chrony";
          user = "chrony";
          group = "chrony";
          mode = "0750";
        }
        "/var/lib/systemd/coredump"
        "/var/lib/systemd/timers"
        "/var/lib/systemd/rfkill"
        "/var/log"
        {
          # DynamicUser=true 服务的 StateDirectory 都落在这，逐个枚举容易漏
          directory = "/var/lib/private";
          mode = "0700";
        }
        "/var/lib/bluetooth"
        "/var/lib/fwupd"
        "/var/lib/power-profiles-daemon"
        "/var/lib/sbctl"
        "/var/lib/flatpak"
        "/var/lib/upower"
        "/var/lib/nbfc"
        "/var/lib/lastlog"
        "/var/lib/containers"
        "/var/lib/cni"
        "/var/lib/cloudflare-warp"
        "/var/lib/docker" # 目前多数主机可能还没用到，先占位，真正启用时数据从一开始就在
        "/var/lib/libvirt"
        "/etc/libvirt"
      ];
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
        # {
        #   # users.mutableUsers 默认 true，密码只靠 passwd 设置，没有声明式来源，
        #   # 唯一的密码哈希就在这——不保留的话每次开机密码直接消失
        #   file = "/etc/shadow";
        #   group = "shadow";
        #   mode = "0640";
        # }
        {
          file = "/etc/ssh/ssh_host_ed25519_key";
          how = "bindmount";
          mode = "0600";
          configureParent = true;
          inInitrd = true;
        }
        {
          file = "/etc/ssh/ssh_host_ed25519_key.pub";
          how = "bindmount";
          configureParent = true;
          inInitrd = true;
        }
        {
          file = "/etc/ssh/ssh_host_rsa_key";
          how = "bindmount";
          mode = "0600";
          configureParent = true;
          inInitrd = true;
        }
        {
          file = "/etc/ssh/ssh_host_rsa_key.pub";
          how = "bindmount";
          configureParent = true;
          inInitrd = true;
        }
        {
          file = "/var/lib/systemd/random-seed";
          how = "symlink";
          inInitrd = true;
          configureParent = true;
        }
      ];
    };
  };
}
