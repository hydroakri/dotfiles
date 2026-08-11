{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../options.nix ];

  options.modules.security = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH authorized keys added to root";
    };
    u2fMappings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Contents of /etc/u2f_mappings (pamu2fcfg -n format); leave empty to disable u2f PAM";
    };
  };

  config = {
    # TODO: 以下两个模块上游尚未支持 linux 7.x，待修复后启用
    # boot.extraModulePackages = [ config.boot.kernelPackages.lkrg ];  # LKRG: lkrg-1.0.0 不兼容 kernel 7.x (sockaddr_unsized API 变更)
    # "p_lkrg"  # tirdad: 需要 CONFIG_LIVEPATCH=y，且依赖上游修复
    boot.kernelParams = [
      "mitigations=auto"
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"
      "bdev_allow_write_mounted=0"
      "erst_disable"
      "extra_latent_entropy"
      "hash_pointers=always"
      "iommu=strict"
      "proc_mem.force_override=ptrace"
      "lockdown=confidentiality"
      # "lockdown=integrity"
      # slightly performance loss
      "cfi=kcfi"
      "init_on_alloc=1"
      "vdso32=0"
      "debugfs=off"
      "random.trust_cpu=0"
      "random.trust_bootloader=0"
      "oops=panic"
      # lockdown=confidentiality + zram 已让休眠不可用；显式禁用防止替换休眠镜像恢复内核
      "nohibernate"
      "kfence.sample_interval=100"
      # 提高 HWRNG 对内核熵池的贡献质量（ANSSI R8）
      "rng_core.default_quality=500"
      # "slub_debug=FZP" 内存分配调试（完整性检查+红区+填毒），开发排查用；生产/游戏负载有 10-20% 开销，暂不启用
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
      "vsyscall=none"
      "efi=disable_early_pci_dma"
      "efi_pstore.pstore_disable=1"
    ];
    # jitterentropy_rng：基于 CPU 执行时间抖动的额外熵源模块
    boot.kernelModules = [ "jitterentropy_rng" ];
    # 关闭连接跟踪辅助模块，防某些 NAT/协议辅助相关攻击；proxy/router 模块已经
    # 在用 nftables/conntrack
    boot.extraModprobeConfig = ''
      options nf_conntrack nf_conntrack_helper=0
    '';
    boot.kernel.sysctl = lib.mkMerge [
      # ── 基础安全基线（所有主机）────────────────────────────────────────
      # 优先级：mkForce/mkOverride 50 > plain 100 > mkOverride 900（服务器
      # 严格模式 + performance/proxy/router 的有意覆盖）> mkOverride 950（本
      # 基线）> mkDefault/其他默认值 1000。基线用 950 而非 mkDefault，避免与
      # nixpkgs 自身模块（如 systemd/coredump.nix）的 mkDefault 赋值冲突。
      (
        {
          # Security (common)
          "kernel.printk_devkmsg" = lib.mkOverride 950 "off";
          # when '3' can cause steam games stop working
          "kernel.yama.ptrace_scope" = lib.mkOverride 950 1;
          # 1 = 仅禁非特权用户；服务器块覆盖为 2（完全禁止）
          "kernel.io_uring_disabled" = lib.mkOverride 950 1;
          "dev.tty.legacy_tiocsti" = lib.mkOverride 950 0;
          # 开启 SYN Cookies，防御 SYN Flood 洪水攻击
          "net.ipv4.tcp_syncookies" = lib.mkOverride 950 1;
          # 开启 RFC1337，防御 TIME-WAIT Assassination 攻击
          "net.ipv4.tcp_rfc1337" = lib.mkOverride 950 1;
          "net.mptcp.enabled" = lib.mkOverride 950 0; # 多路径 TCP 用不到，少一分协议解析攻击面
          "vm.memfd_noexec" = lib.mkOverride 950 1; # 禁止创建可执行匿名内存文件，防无文件恶意代码/JIT 喷射
          # 禁止 TCP 时间戳，防止远端推算系统运行时间（侧信道）；performance.nix
          # 启用时以 mkOverride 900 覆盖为 1（TCP timestamps 对性能有益）
          "net.ipv4.tcp_timestamps" = lib.mkOverride 950 0;
          # 记录火星包是安全的，它不丢包，只记日志
          "net.ipv4.conf.all.log_martians" = lib.mkOverride 950 1;
          "net.ipv4.conf.default.log_martians" = lib.mkOverride 950 1;
          # 严格模式 (1)，这是安全的默认基线
          # (如果开启了透明代理，proxy.nix 会自动将其覆盖为松散模式 2)
          "net.ipv4.conf.all.rp_filter" = lib.mkOverride 950 1;
          "net.ipv4.conf.default.rp_filter" = lib.mkOverride 950 1;
          # 禁止接受 ICMP 重定向 (防止中间人攻击篡改路由表)
          # 普通主机不需要接受重定向，除非充当路由器
          "net.ipv4.conf.*.accept_redirects" = lib.mkOverride 950 0;
          "net.ipv4.conf.*.send_redirects" = lib.mkOverride 950 0;
          "net.ipv6.conf.*.accept_redirects" = lib.mkOverride 950 0;
          "net.ipv4.conf.*.shared_media" = lib.mkOverride 950 0;
          # 禁止源路由 (Source Routing)
          "net.ipv4.conf.*.accept_source_route" = lib.mkOverride 950 0;
          "net.ipv6.conf.*.accept_source_route" = lib.mkOverride 950 0;
          # ARP 硬化：防止 ARP 缓存中毒和跨接口响应；router.nix 可在路由拓扑下覆盖放松
          "net.ipv4.conf.*.arp_filter" = lib.mkOverride 950 1;
          "net.ipv4.conf.*.arp_ignore" = lib.mkOverride 950 2;
          "net.ipv4.conf.*.arp_announce" = lib.mkOverride 950 2;
          "net.ipv4.conf.all.drop_gratuitous_arp" = lib.mkOverride 950 1;
          # 忽略违规的 ICMP 错误消息
          "net.ipv4.icmp_ignore_bogus_error_responses" = lib.mkOverride 950 1;
          # 忽略广播 ICMP echo，防御 Smurf 放大攻击
          "net.ipv4.icmp_echo_ignore_broadcasts" = lib.mkOverride 950 1;
          # Disable ICMP echo（ping）, use TCP ping instead
          "net.ipv4.icmp_echo_ignore_all" = lib.mkOverride 950 1;
          "net.ipv6.icmp.echo_ignore_all" = lib.mkOverride 950 1;
          "net.ipv4.conf.all.secure_redirects" = lib.mkOverride 950 1;
          "net.ipv4.conf.default.secure_redirects" = lib.mkOverride 950 1;
          "net.ipv4.tcp_dsack" = lib.mkOverride 950 0;
          "net.ipv4.tcp_fack" = lib.mkOverride 950 0;
          # 防止 loopback 地址通过非 loopback 接口路由（ANSSI R12）
          "net.ipv4.conf.all.route_localnet" = lib.mkOverride 950 0;
          # 拒绝源地址属于本机接口的入站包，防止反射攻击（ANSSI R12）
          "net.ipv4.conf.all.accept_local" = lib.mkOverride 950 0;
          # 临时端口范围收窄，减少端口猜测攻击面（ANSSI R12）
          "net.ipv4.ip_local_port_range" = lib.mkOverride 950 "32768 65535";
          # 增加 BPF JIT 编译器的安全性，消除某些侧信道攻击
          "net.core.bpf_jit_harden" = lib.mkOverride 950 2;
          # 禁止非特权用户调用 eBPF (除非你在进行内核级开发，否则建议开启)
          "kernel.unprivileged_bpf_disabled" = lib.mkOverride 950 1;
          # 限制内核指针地址泄露 (防止攻击者探测内核内存布局)
          "kernel.kptr_restrict" = lib.mkOverride 950 2;
          # 限制 dmesg 日志访问权限 (防止普通用户查看启动日志中的敏感信息)
          "kernel.dmesg_restrict" = lib.mkOverride 950 1;
          # 增加内核崩溃和警告的阈值限制，防止日志泛滥
          "kernel.oops_limit" = lib.mkOverride 950 100;
          "kernel.warn_limit" = lib.mkOverride 950 100;
          "kernel.panic" = lib.mkOverride 950 (-1);
          # 核心转储 piping 给 /bin/false 直接丢弃；systemd/coredump.nix 自己用
          # mkDefault "core" 设置同一 key，这也是本块整体用 950 而非 mkDefault 的原因
          "kernel.core_pattern" = lib.mkOverride 950 "|/bin/false";
          # 禁止加载新的 TTY 线路规程 (减少内核攻击面)
          "dev.tty.ldisc_autoload" = lib.mkOverride 950 0;
          # 禁止 kexec (防止在不经过 BIOS 自检的情况下热加载新内核)
          # 注意：这会禁用 kdump 和 systemctl kexec 快速重启功能
          "kernel.kexec_load_disabled" = lib.mkOverride 950 1;
          # 增加 mmap 内存分配的随机性 (ASLR)，增加缓冲区溢出攻击的难度
          "vm.mmap_rnd_compat_bits" = lib.mkOverride 950 16;
          # 强制开启地址空间布局随机化
          "kernel.randomize_va_space" = lib.mkOverride 950 2;
          # 限制性能分析工具 (Perf) 的使用权限
          # 2 = 仅 root 可用 perf（开发者临时 doas 即可）；服务器块覆盖为 3（完全禁止）
          "kernel.perf_event_paranoid" = lib.mkOverride 950 2;
          # 限制 perf 最多占用 1% CPU，防止侧信道探测同时不破坏性能分析功能（ANSSI R9）
          "kernel.perf_cpu_time_max_percent" = lib.mkOverride 950 1;
          # 限制非特权用户采样速率，进一步阻断计时侧信道（securix R9）
          "kernel.perf_event_max_sample_rate" = lib.mkOverride 950 1;
          # kernel.sysrq 已在 core.nix 设为 246（仅启用安全子集，非全量），不再重复定义
          # 禁止程序使用内存最低的 64KB 地址 (防止 NULL 指针解引用攻击)
          "kernel.core_uses_pid" = lib.mkOverride 950 1;
          # Core dump 文件名带 PID，防止竞态覆盖攻击
          "vm.mmap_min_addr" = lib.mkOverride 950 65536;
          # 限制非特权用户使用 userfaultfd
          # 注意：极少数高性能虚拟机特性可能依赖此项，一般桌面使用无影响
          "vm.unprivileged_userfaultfd" = lib.mkOverride 950 0;
          # 禁止 SUID 程序在崩溃时产生 Core Dump
          # 防止特权程序的内存数据（可能含密码）泄露到磁盘
          "fs.suid_dumpable" = lib.mkOverride 950 0;
          # 文件系统链接保护 (防止 /tmp 目录下的竞争条件攻击)
          "fs.protected_regular" = lib.mkOverride 950 2;
          "fs.protected_fifos" = lib.mkOverride 950 2;
          "fs.protected_hardlinks" = lib.mkOverride 950 1;
          "fs.protected_symlinks" = lib.mkOverride 950 1;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
          "vm.mmap_rnd_bits" = lib.mkOverride 950 32;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isAarch64 {
          "vm.mmap_rnd_bits" = lib.mkOverride 950 24;
        }
      )

      # ── 服务器严格模式（无桌面/游戏场景）────────────────────────────────
      # mkOverride 900：比上方基线（950）强，收严非桌面主机；仍弱于 plain 用户赋值。
      (lib.mkIf (!config.services.displayManager.enable) {
        # 完全禁止 io_uring（桌面 mkDefault 1 兼容部分程序）
        "kernel.io_uring_disabled" = lib.mkOverride 900 2;
        # 完全禁止 perf（桌面 mkDefault 2 保留 root 权限使用）
        "kernel.perf_event_paranoid" = lib.mkOverride 900 3;
        # 禁用 binfmt_misc（桌面保留以支持 Wine/binfmt-runner）
        "fs.binfmt_misc.status" = lib.mkOverride 900 0;
      })
    ];
    systemd.coredump.enable = lib.mkDefault false;
    # ulimit 层再禁一次 coredump（systemd.coredump 管 systemd-coredump 服务路径，
    # 这里是内核层面直接阻止）；加大 memlock 供 GPG/密码管理器锁敏感内存不被换到 swap
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "hard";
        item = "core";
        value = "0";
      }
      {
        domain = "*";
        type = "soft";
        item = "core";
        value = "0";
      }
      {
        domain = "*";
        type = "hard";
        item = "memlock";
        value = "2147484";
      }
      {
        domain = "*";
        type = "soft";
        item = "memlock";
        value = "2147484";
      }
    ];
    # 调高默认文件描述符上限，避免开发工具/游戏吃满默认值；DumpCore=false 与已禁 coredump 一致
    systemd.settings.Manager = {
      DefaultLimitNOFILE = "2048:2097152";
      DumpCore = false;
    };
    systemd.user.settings.Manager = {
      DefaultLimitNOFILE = "1024:1048576";
      DumpCore = false;
    };
    # systemd-pstore 没有对应的 NixOS 选项包装，直接写配置文件；关闭跨重启崩溃
    # 信息持久化（EFI pstore/ACPI ERST），与已有的 "erst_disable" 内核参数呼应
    environment.etc."systemd/pstore.conf.d/hardening.conf".text = ''
      [PStore]
      Storage=none
    '';
    # 每次启动清理 /tmp 和 /var/tmp，防止上次会话残留的敏感数据（srvos）
    boot.tmp.cleanOnBoot = lib.mkDefault true;
    # ANSSI R33：审计权限提升与凭证变更事件（不审计 execve，避免桌面/游戏性能损耗）
    # security.auditd.enable = true;
    security.unprivilegedUsernsClone = lib.mkDefault false;
    environment.memoryAllocator.provider = lib.mkDefault "graphene-hardened-light"; # balance:scudo performance:mimalloc security:graphene-hardened-light
    environment.systemPackages = [
      pkgs.ssh-copy-id
      # keepassxc # installed in flatpak

      # For sops-nix
      pkgs.age
      pkgs.sops
      pkgs.ssh-to-age
      pkgs.age-plugin-fido2-hmac

      # For fido2 security keys
      pkgs.pam_u2f
      pkgs.libfido2
      pkgs.yubikey-manager

      # sudo → doas compatibility shim
      pkgs.doas-sudo-shim

    ];
    security = {
      sudo-rs.enable = lib.mkDefault false;
      sudo.enable = lib.mkDefault false;
      doas = {
        enable = lib.mkDefault true;
        extraRules = [
          {
            groups = [ "wheel" ];
            persist = true;
            keepEnv = true;
          }
        ];
      };
      apparmor = {
        enable = lib.mkDefault true;
        killUnconfinedConfinables = lib.mkDefault true;
        packages = [ pkgs.apparmor-profiles ];
      };
    };
    networking.firewall = {
      enable = lib.mkDefault true;
      allowedTCPPorts = [ 22 ];
    };

    services.usbguard = {
      enable = lib.mkDefault true;
      presentDevicePolicy = lib.mkDefault "allow";
      IPCAllowedUsers = [
        "root"
        config.mainUser
      ];
    };

    systemd.user.services.usbguard-notifier = {
      description = "USBGuard device notifier";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.usbguard-notifier}/bin/usbguard-notifier";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
    # ===========================================================================
    #PAM
    security.pam = {
      u2f = {
        enable = lib.mkDefault (config.modules.security.u2fMappings != "");
        settings = {
          cue = true;
          authfile = "/etc/u2f_mappings";
          interactive = true;
        };
      };
      services = {
        doas.u2fAuth = lib.mkDefault (config.modules.security.u2fMappings != "");
        login.u2fAuth = lib.mkDefault (config.modules.security.u2fMappings != "");

        system-login.failDelay.enable = lib.mkDefault true;
        system-login.failDelay.delay = lib.mkDefault 4000000;
        passwd.rules.password.unix.settings.rounds = lib.mkDefault 65536;
        su.requireWheel = lib.mkDefault true;
      };
    };
    # plug u2f device & use `pamu2fcfg -n`, then set modules.security.u2fMappings in your host config
    environment.etc."u2f_mappings" = lib.mkIf (config.modules.security.u2fMappings != "") {
      text = config.modules.security.u2fMappings;
    };

    # ===========================================================================
    # who can login in THIS machine
    # initialze security key: `ssh-keygen -t ed25519-sk -O resident -O verify-required`
    # add sk: `ssh-add -K`
    # get public key from sk: `ssh-keygen -K`
    # set password: `ssh-keygen -p -f <file name>`
    services.pcscd.enable = lib.mkDefault true;

    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "prohibit-password";
        X11Forwarding = lib.mkDefault false;
        AllowTcpForwarding = lib.mkDefault "no";
        AllowStreamLocalForwarding = lib.mkDefault false;
        # Ciphers/KexAlgorithms narrowed beyond NixOS's default set; Macs left
        # alone (already matches via enableRecommendedAlgorithms).
        AllowAgentForwarding = lib.mkDefault false;
        ClientAliveCountMax = lib.mkDefault 2;
        Compression = lib.mkDefault false;
        MaxAuthTries = lib.mkDefault 3;
        MaxSessions = lib.mkDefault 2;
        TCPKeepAlive = lib.mkDefault false;
        PrintMotd = lib.mkDefault false;
        UsePAM = lib.mkDefault true;
        # Only ever offer/generate-preferring the ed25519 host key, not RSA/ECDSA.
        HostKey = lib.mkDefault "/etc/ssh/ssh_host_ed25519_key";
        HostKeyAlgorithms = lib.mkDefault "ssh-ed25519";
        PubkeyAcceptedAlgorithms = lib.mkDefault "ssh-ed25519,sk-ssh-ed25519@openssh.com";
        Ciphers = lib.mkDefault [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
        ];
        KexAlgorithms = lib.mkDefault [
          "sntrup761x25519-sha512"
          "sntrup761x25519-sha512@openssh.com"
          "mlkem768x25519-sha256"
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
        ];
      };
    };
    users.users.root.openssh.authorizedKeys.keys = config.modules.security.authorizedKeys;
    # =============================================================================
    # This machine can signing/control key from WHERE?
    programs.git.config = {

      # GIT Signing
      # DISABLE Verified Signing by default
      # non-root User should use `git config --global commit.gpgsign true`
      # signing need user's email dont't foget `git config --global user.email "THE EMAIL"`
      # and add public key for each repo `git config --global user.signingkey "THE PUBLIC KEY"`
      commit.gpgsign = lib.mkDefault false;
      gpg.format = lib.mkDefault "ssh";

      # GIT VERIFING — set allowedSignersFile per-host via sops (see omen15.nix)
    };
    programs.ssh = {
      extraConfig = ''
        Host *
          # ForwardAgent yes # open only in trusted machine
          AddKeysToAgent yes
          ControlMaster auto
          ControlPath /run/user/%i/ssh-mux-%C
          ControlPersist 10m

          IdentitiesOnly no # let ssh-agent auto find keys
          # To use specific keys, try `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 user@host`

          # Mirrors the server-side narrowing above.
          VisualHostKey yes
          Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
          MACs umac-128-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
          KexAlgorithms sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,mlkem768x25519-sha256,curve25519-sha256,curve25519-sha256@libssh.org
          HostKeyAlgorithms sk-ssh-ed25519@openssh.com,ssh-ed25519
          PubkeyAcceptedAlgorithms sk-ssh-ed25519@openssh.com,ssh-ed25519
      '';
    };
    # 拉黑老旧/冷门硬件驱动（DVB/采集卡、老式 framebuffer、gameport、FireWire、
    # RDMA、冷门网络协议、旧输入设备、冷门文件系统等）。排除在外：CAN 总线、
    # NFS/CIFS、Thunderbolt、蓝牙、joydev、RNDIS（仍可能用得上）。
    boot.blacklistedKernelModules = [
      "6lowpan"
      "9p"
      "9pnet"
      "9pnet_fd"
      "9pnet_rdma"
      "9pnet_usbg"
      "9pnet_virtio"
      "9pnet_xen"
      "a3d"
      "a8293"
      "adc-joystick"
      "adfs"
      "adi"
      "aer_inject"
      "af9013"
      "af9033"
      "af_802154"
      "af_key"
      "affs"
      "afs"
      "agilent_82350b"
      "agilent_82357a"
      "ah4"
      "ah6"
      "altera-ci"
      "amd76x_edac"
      "analog"
      "appletalk"
      "as102_fe"
      "ascot2e"
      "asus_acpi"
      "atbm8830"
      "ath_pci"
      "ati_remote"
      "ati_remote2"
      "atm"
      "atmtcp"
      "aty128fb"
      "atyfb"
      "au0828"
      "au8522_common"
      "au8522_decoder"
      "au8522_dig"
      "auth_rpcgss"
      "ax25"
      "b2c2-flexcop"
      "b2c2-flexcop-pci"
      "b2c2-flexcop-usb"
      "batman-adv"
      "bcm3510"
      "bcm43xx"
      "befs"
      "brcm80211"
      "bt819"
      "bt856"
      "bt866"
      "bt878"
      "bttv"
      "budget"
      "budget-av"
      "budget-ci"
      "budget-core"
      "cb7210"
      "cdrom"
      "cec_gpib"
      "ceph"
      "cirrusfb"
      "cobra"
      "coda"
      "cramfs"
      "cx18"
      "cx18-alsa"
      "cx22700"
      "cx22702"
      "cx231xx"
      "cx231xx-alsa"
      "cx231xx-dvb"
      "cx23885"
      "cx24110"
      "cx24113"
      "cx24116"
      "cx24117"
      "cx24120"
      "cx24123"
      "cx88-alsa"
      "cx88-blackbird"
      "cx88-dvb"
      "cx88-vp3054-i2c"
      "cx8800"
      "cx8802"
      "cx88xx"
      "cxd2099"
      "cxd2820r"
      "cxd2841er"
      "cxd2880-spi"
      "cyber2000fb"
      "cyblafb"
      "db9"
      "dccp"
      "ddbridge"
      "ddbridge-dummy-fe"
      "de4x5"
      "decnet"
      "dib0070"
      "dib0090"
      "dib3000mb"
      "dib3000mc"
      "dib7000m"
      "dib7000p"
      "dib8000"
      "dibx000_common"
      "dlm"
      "dm1105"
      "dp83tg720"
      "drx39xyj"
      "drxd"
      "drxk"
      "ds3000"
      "dsbr100"
      "dst"
      "dst_ca"
      "dummy_hcd"
      "dv1394"
      "dvb-as102"
      "dvb-bt8xx"
      "dvb-core"
      "dvb-pll"
      "dvb-ttusb-budget"
      "dvb-usb"
      "dvb-usb-a800"
      "dvb-usb-af9005"
      "dvb-usb-af9005-remote"
      "dvb-usb-af9015"
      "dvb-usb-af9035"
      "dvb-usb-anysee"
      "dvb-usb-au6610"
      "dvb-usb-az6007"
      "dvb-usb-az6027"
      "dvb-usb-ce6230"
      "dvb-usb-cinergyT2"
      "dvb-usb-cxusb"
      "dvb-usb-dib0700"
      "dvb-usb-dibusb-common"
      "dvb-usb-dibusb-mb"
      "dvb-usb-dibusb-mc"
      "dvb-usb-dibusb-mc-common"
      "dvb-usb-digitv"
      "dvb-usb-dtt200u"
      "dvb-usb-dtv5100"
      "dvb-usb-dvbsky"
      "dvb-usb-dw2102"
      "dvb-usb-ec168"
      "dvb-usb-gl861"
      "dvb-usb-gp8psk"
      "dvb-usb-lmedm04"
      "dvb-usb-m920x"
      "dvb-usb-mxl111sf"
      "dvb-usb-nova-t-usb2"
      "dvb-usb-opera"
      "dvb-usb-pctv452e"
      "dvb-usb-rtl28xxu"
      "dvb-usb-technisat-usb2"
      "dvb-usb-ttusb2"
      "dvb-usb-umt-010"
      "dvb-usb-vp702x"
      "dvb-usb-vp7045"
      "dvb_usb_v2"
      "e4000"
      "earth-pt1"
      "earth-pt3"
      "ec100"
      "econet"
      "ecryptfs"
      "eepro100"
      "em28xx"
      "em28xx-alsa"
      "em28xx-dvb"
      "em28xx-rc"
      "em28xx-v4l"
      "ene_ir"
      "erdma"
      "esp4"
      "esp4_offload"
      "esp6"
      "esp6_offload"
      "eth1394"
      "evbug"
      "fc0011"
      "fc0012"
      "fc0013"
      "fc2580"
      "fintek-cir"
      "firedtv"
      "firewire-core"
      "firewire-net"
      "firewire-ohci"
      "firewire-sbp2"
      "firewire_core"
      "firewire_ohci"
      "firewire_sbp2"
      "floppy"
      "freevxfs"
      "gamecon"
      "gameport"
      "garmin_gps"
      "gf2k"
      "gfs2"
      "gnss"
      "gnss-mtk"
      "gnss-serial"
      "gnss-sirf"
      "gnss-ubx"
      "gnss-usb"
      "go7007"
      "go7007-loader"
      "go7007-usb"
      "gp8psk-fe"
      "gpib_common"
      "grace"
      "grip"
      "grip_mp"
      "gspca_benq"
      "gspca_conex"
      "gspca_cpia1"
      "gspca_dtcs033"
      "gspca_etoms"
      "gspca_finepix"
      "gspca_gl860"
      "gspca_jeilinj"
      "gspca_jl2005bcd"
      "gspca_kinect"
      "gspca_konica"
      "gspca_m5602"
      "gspca_main"
      "gspca_mars"
      "gspca_mr97310a"
      "gspca_nw80x"
      "gspca_ov519"
      "gspca_ov534"
      "gspca_ov534_9"
      "gspca_pac207"
      "gspca_pac7302"
      "gspca_pac7311"
      "gspca_se401"
      "gspca_sn9c2028"
      "gspca_sn9c20x"
      "gspca_sonixb"
      "gspca_sonixj"
      "gspca_spca1528"
      "gspca_spca500"
      "gspca_spca501"
      "gspca_spca505"
      "gspca_spca506"
      "gspca_spca508"
      "gspca_spca561"
      "gspca_sq905"
      "gspca_sq905c"
      "gspca_sq930x"
      "gspca_stk014"
      "gspca_stk1135"
      "gspca_stv0680"
      "gspca_stv06xx"
      "gspca_sunplus"
      "gspca_t613"
      "gspca_topro"
      "gspca_touptek"
      "gspca_tv8532"
      "gspca_vc032x"
      "gspca_vicam"
      "gspca_xirlink_cit"
      "gspca_zc3xx"
      "guillemot"
      "gx1fb"
      "hamradio"
      "hdlcdrv"
      "hdpvr"
      "helene"
      "hexium_gemini"
      "hexium_orion"
      "hfs"
      "hfsplus"
      "hgafb"
      "hid-pxrc"
      "hopper"
      "horus3a"
      "hwpoison-inject"
      "i2c-parport"
      "i810fb"
      "iTCO_wdt"
      "ieee802154_6lowpan"
      "iforce"
      "iforce-serio"
      "iforce-usb"
      "igorplugusb"
      "iguanair"
      "imon"
      "imon_raw"
      "ines_gpib"
      "intelfb"
      "interact"
      "ionic_rdma"
      "ipcomp"
      "ipcomp6"
      "ipx"
      "ir-imon-decoder"
      "ir-jvc-decoder"
      "ir-kbd-i2c"
      "ir-mce_kbd-decoder"
      "ir-nec-decoder"
      "ir-rc5-decoder"
      "ir-rc6-decoder"
      "ir-rcmm-decoder"
      "ir-sanyo-decoder"
      "ir-sharp-decoder"
      "ir-sony-decoder"
      "ir-usb"
      "ir-xmp-decoder"
      "ir_toy"
      "irdma"
      "isl6405"
      "isl6421"
      "isl6423"
      "it913x"
      "itd1000"
      "ite-cir"
      "ivtv"
      "ivtvfb"
      "ix2505v"
      "jffs2"
      "jfs"
      "joydump"
      "kafs"
      "kyrofb"
      "l2tp_core"
      "l2tp_debugfs"
      "l2tp_eth"
      "l2tp_ip"
      "l2tp_ip6"
      "l2tp_netlink"
      "l2tp_ppp"
      "l64781"
      "lg2160"
      "lgdt3305"
      "lgdt3306a"
      "lgdt330x"
      "lgs8gxx"
      "lnbh25"
      "lnbp21"
      "lnbp22"
      "lockd"
      "lp"
      "lpvo_usb_gpib"
      "lxfb"
      "m88ds3103"
      "m88rs2000"
      "m88rs6000t"
      "magellan"
      "mantis"
      "mantis_core"
      "marvell-88q2xxx"
      "marvell-88x2222"
      "matroxfb_base"
      "max2165"
      "max9271"
      "mb86a16"
      "mb86a20s"
      "mc44s803"
      "mce-inject"
      "mceusb"
      "mctp-i3c"
      "mctp-serial"
      "mctp-usb"
      "microchip_t1s"
      "minix"
      "mn88472"
      "mn88473"
      "mt2060"
      "mt2063"
      "mt20xx"
      "mt2131"
      "mt2266"
      "mt312"
      "mt352"
      "mtdram"
      "mxb"
      "mxl111sf-demod"
      "mxl111sf-tuner"
      "mxl301rf"
      "mxl5005s"
      "mxl5007t"
      "mxl5xx"
      "mxl692"
      "n-hdlc"
      "nandsim"
      "nec7210"
      "neofb"
      "netconsole"
      "netrom"
      "netup-unidvb"
      "nft_xfrm"
      "ngene"
      "ni_usb_gpib"
      "nilfs2"
      "nosy"
      "nuvoton-cir"
      "nvidiafb"
      "nvme-rdma"
      "nvmet-rdma"
      "nxt200x"
      "nxt6000"
      "ocfs2"
      "ocfs2_dlm"
      "ocfs2_dlmfs"
      "ocfs2_nodemanager"
      "ocfs2_stack_o2cb"
      "ocfs2_stack_user"
      "ocfs2_stackglue"
      "ocrdma"
      "ohci1394"
      "or51132"
      "or51211"
      "orangefs"
      "p8022"
      "p8023"
      "parport"
      "parport_cs"
      "parport_pc"
      "parport_serial"
      "pcspkr"
      "pluto2"
      "pm2fb"
      "pmt_class"
      "pmt_crashlog"
      "pmt_telemetry"
      "ppdev"
      "pppoatm"
      "pps_parport"
      "prism54"
      "psnap"
      "psxpad-spi"
      "pvrusb2"
      "pxrc"
      "qm1d1b0004"
      "qm1d1c0042"
      "qt1010"
      "qwiic-joystick"
      "r820t"
      "radeonfb"
      "radio-keene"
      "radio-ma901"
      "radio-maxiradio"
      "radio-mr800"
      "radio-shark"
      "radio-si470x-common"
      "radio-si470x-i2c"
      "radio-si470x-usb"
      "radio-tea5764"
      "raw1394"
      "rc-adstech-dvb-t-pci"
      "rc-alink-dtu-m"
      "rc-anysee"
      "rc-apac-viewcomp"
      "rc-astrometa-t2hybrid"
      "rc-asus-pc39"
      "rc-asus-ps3-100"
      "rc-ati-tv-wonder-hd-600"
      "rc-ati-x10"
      "rc-avermedia"
      "rc-avermedia-a16d"
      "rc-avermedia-cardbus"
      "rc-avermedia-dvbt"
      "rc-avermedia-m135a"
      "rc-avermedia-m733a-rm-k6"
      "rc-avermedia-rm-ks"
      "rc-avertv-303"
      "rc-azurewave-ad-tu700"
      "rc-beelink-gs1"
      "rc-beelink-mxiii"
      "rc-behold"
      "rc-behold-columbus"
      "rc-budget-ci-old"
      "rc-cinergy"
      "rc-cinergy-1400"
      "rc-ct-90405"
      "rc-d680-dmb"
      "rc-delock-61959"
      "rc-dib0700-nec"
      "rc-dib0700-rc5"
      "rc-digitalnow-tinytwin"
      "rc-digittrade"
      "rc-dm1105-nec"
      "rc-dntv-live-dvb-t"
      "rc-dntv-live-dvbt-pro"
      "rc-dreambox"
      "rc-dtt200u"
      "rc-dvbsky"
      "rc-dvico-mce"
      "rc-dvico-portable"
      "rc-em-terratec"
      "rc-encore-enltv"
      "rc-encore-enltv-fm53"
      "rc-encore-enltv2"
      "rc-evga-indtube"
      "rc-eztv"
      "rc-flydvb"
      "rc-flyvideo"
      "rc-fusionhdtv-mce"
      "rc-gadmei-rm008z"
      "rc-geekbox"
      "rc-genius-tvgo-a11mce"
      "rc-gotview7135"
      "rc-hauppauge"
      "rc-hisi-poplar"
      "rc-hisi-tv-demo"
      "rc-imon-mce"
      "rc-imon-pad"
      "rc-imon-rsc"
      "rc-iodata-bctv7e"
      "rc-it913x-v1"
      "rc-it913x-v2"
      "rc-kaiomy"
      "rc-khadas"
      "rc-khamsin"
      "rc-kworld-315u"
      "rc-kworld-pc150u"
      "rc-kworld-plus-tv-analog"
      "rc-leadtek-y04g0051"
      "rc-lme2510"
      "rc-loopback"
      "rc-manli"
      "rc-mecool-kii-pro"
      "rc-mecool-kiii-pro"
      "rc-medion-x10"
      "rc-medion-x10-digitainer"
      "rc-medion-x10-or2x"
      "rc-minix-neo"
      "rc-msi-digivox-ii"
      "rc-msi-digivox-iii"
      "rc-msi-tvanywhere"
      "rc-msi-tvanywhere-plus"
      "rc-mygica-utv3"
      "rc-nebula"
      "rc-nec-terratec-cinergy-xs"
      "rc-norwood"
      "rc-npgtech"
      "rc-odroid"
      "rc-pctv-sedna"
      "rc-pine64"
      "rc-pinnacle-color"
      "rc-pinnacle-grey"
      "rc-pinnacle-pctv-hd"
      "rc-pixelview"
      "rc-pixelview-002t"
      "rc-pixelview-mk12"
      "rc-pixelview-new"
      "rc-powercolor-real-angel"
      "rc-proteus-2309"
      "rc-purpletv"
      "rc-pv951"
      "rc-rc6-mce"
      "rc-real-audio-220-32-keys"
      "rc-reddo"
      "rc-siemens-gigaset-rc20"
      "rc-snapstream-firefly"
      "rc-streamzap"
      "rc-su3000"
      "rc-tanix-tx3mini"
      "rc-tanix-tx5max"
      "rc-tbs-nec"
      "rc-technisat-ts35"
      "rc-technisat-usb2"
      "rc-terratec-cinergy-c-pci"
      "rc-terratec-cinergy-s2-hd"
      "rc-terratec-cinergy-xs"
      "rc-terratec-slim"
      "rc-terratec-slim-2"
      "rc-tevii-nec"
      "rc-tivo"
      "rc-total-media-in-hand"
      "rc-total-media-in-hand-02"
      "rc-trekstor"
      "rc-tt-1500"
      "rc-twinhan-dtv-cab-ci"
      "rc-twinhan1027"
      "rc-vega-s9x"
      "rc-videomate-m1f"
      "rc-videomate-s350"
      "rc-videomate-tv-pvr"
      "rc-videostrong-kii-pro"
      "rc-wetek-hub"
      "rc-wetek-play2"
      "rc-winfast"
      "rc-winfast-usbii-deluxe"
      "rc-x96max"
      "rc-xbox-360"
      "rc-xbox-dvd"
      "rc-zx-irdec"
      "rdma_cm"
      "rdma_rxe"
      "rdma_ucm"
      "rdmavt"
      "rds"
      "rds_rdma"
      "rds_tcp"
      "reiserfs"
      "ring_buffer_benchmark"
      "rivafb"
      "romfs"
      "rose"
      "rpcrdma"
      "rpcsec_gss_krb5"
      "rtl2830"
      "rtl2832"
      "rxrpc"
      "s1d13xxxfb"
      "s5h1409"
      "s5h1411"
      "s5h1420"
      "s921"
      "saa6588"
      "saa7134"
      "saa7134-alsa"
      "saa7134-dvb"
      "saa7134-empress"
      "saa7134-go7007"
      "saa7146"
      "saa7146_vv"
      "saa7164"
      "saa7706h"
      "savagefb"
      "sbp2"
      "scsi_debug"
      "sctp"
      "sctp_diag"
      "serial_ir"
      "shark2"
      "si2157"
      "si2165"
      "si2168"
      "si21xx"
      "sidewinder"
      "sisfb"
      "smc"
      "smc_diag"
      "smipcie"
      "smsdvb"
      "smsmdtv"
      "smssdio"
      "smsusb"
      "snd-bt87x"
      "snd_aw2"
      "snd_intel8x0m"
      "snd_pcsp"
      "sp2"
      "sp5100_tco"
      "sp887x"
      "spaceball"
      "spaceorb"
      "squashfs"
      "sr_mod"
      "sstfb"
      "stb0899"
      "stb6000"
      "stb6100"
      "stinger"
      "streamzap"
      "stv0288"
      "stv0297"
      "stv0299"
      "stv0367"
      "stv0900"
      "stv090x"
      "stv0910"
      "stv6110"
      "stv6110x"
      "stv6111"
      "sunrpc"
      "sysv"
      "tc90522"
      "tda10021"
      "tda10023"
      "tda10048"
      "tda1004x"
      "tda10071"
      "tda10086"
      "tda18212"
      "tda18218"
      "tda18250"
      "tda18271"
      "tda18271c2dd"
      "tda665x"
      "tda8083"
      "tda8261"
      "tda826x"
      "tda827x"
      "tda8290"
      "tda9887"
      "tdfxfb"
      "tea5761"
      "tea5767"
      "tipc"
      "tipc_diag"
      "tmdc"
      "tms9914"
      "tnt4882"
      "trancedriver"
      "tridentfb"
      "ts2020"
      "ttusb_dec"
      "ttusbdecfe"
      "ttusbir"
      "tua6100"
      "tua9001"
      "tuner"
      "tuner-simple"
      "tuner-types"
      "turbografx"
      "twidjoy"
      "ubifs"
      "udf"
      "udlfb"
      "ueagle-atm"
      "ufs"
      "usb_debug"
      "usbatm"
      "usbkbd"
      "usbmouse"
      "ves1820"
      "ves1x93"
      "vesafb"
      "vfb"
      "viafb"
      "video1394"
      "vim2m"
      "vimc"
      "visl"
      "vivid"
      "vkms"
      "vmw_pvrdma"
      "vsock_diag"
      "vt8623fb"
      "walkera0701"
      "warrior"
      "winbond-cir"
      "x25"
      "x86-android-tablets"
      "xbox_remote"
      "xc2028"
      "xc4000"
      "xc5000"
      "xfrm4_tunnel"
      "xfrm6_tunnel"
      "xfrm_algo"
      "xfrm_interface"
      "xfrm_ipcomp"
      "xfrm_iptfs"
      "xfrm_user"
      "xsk_diag"
      "xt_dccp"
      "xt_l2tp"
      "xt_sctp"
      "xusbatm"
      "zd1301"
      "zd1301_demod"
      "zhenhua"
      "zl10036"
      "zl10039"
      "zl10353"
      "zonefs"
    ];
  };
}
