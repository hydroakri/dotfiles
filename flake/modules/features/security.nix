{
  config,
  lib,
  pkgs,
  ...
}:
let
  mainUser = config.mainUser;
  skKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIORKNKURAriDLXiBpCKeuc3aBcIkQJy32I+sOpwMaWUmAAAABHNzaDo= ${mainUser}";
  bakKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE";
  bravePolicy = pkgs.writeText "castration.json" (
    builtins.toJSON {
      # ======= 1. Shields (护盾 - 对应 PG 清单第一部分) =======
      "DefaultBraveAdblockSetting" = 2; # Trackers & ads: Aggressive
      "DefaultBraveHttpsUpgradeSetting" = 2; # Upgrade connections: Strict
      "DefaultBraveFingerprintingV2Setting" = 2; # Block fingerprinting: Strict
      "BlockThirdPartyCookies" = true; # Block third-party cookies
      "DefaultBraveReferrersSetting" = 2; # 引荐来源保护
      "BraveDebouncingEnabled" = true; # 自动跳过中间追踪链接
      "BraveGlobalPrivacyControlEnabled" = true; # 开启 GPC (Global Privacy Control)

      # ======= 2. 隐私与安全 (对应 PG 清单第二部分) =======
      "DefaultJavaScriptOptimizerSetting" = 2; # Don’t allow JS optimization (防JIT)
      "WebRtcIPHandling" = "disable_non_proxied_udp"; # WebRTC IP Policy: Disable non-proxied UDP
      "BraveDeAmpEnabled" = true; # Auto-redirect AMP pages
      "BraveTrackingQueryParametersFilteringEnabled" = true; # Auto-redirect tracking URLs
      "BraveReduceLanguageEnabled" = true; # Language preferences fingerprinting protection

      # ======= 3. Web3、Tor 与商业组件 (对应 PG 清单 Web3/Tor 部分) =======
      "BraveWalletDisabled" = true; # 禁用所有 Web3 (Extensions no fallback)
      "TorDisabled" = true; # 禁用内置 Tor
      "BraveAIChatEnabled" = false; # 禁用 Leo AI
      "BraveTalkDisabled" = true; # 禁用视频会议
      "BraveNewsDisabled" = true; # 禁用新闻流
      "BravePlaylistEnabled" = false; # 禁用播放列表
      "BraveRewardsDisabled" = true;
      "BraveVPNDisabled" = true;
      "PromotionsEnabled" = false; # 禁用 Promotions

      # ======= 4. 数据收集 (对应 PG 清单数据收集部分) =======
      "BraveP3AEnabled" = false; # Uncheck P3A
      "BraveStatsPingEnabled" = false; # Uncheck daily usage ping
      "MetricsReportingEnabled" = false; # Uncheck diagnostic reports
      "BraveWebDiscoveryEnabled" = false; # 彻底禁掉 WDP 采集

      # ======= 5. 系统与搜索 (对应 PG 清单最后部分) =======
      "SearchSuggestEnabled" = false; # Uncheck search suggestions
      "BackgroundModeEnabled" = false; # Uncheck background apps
      "SafeBrowsingExtendedReportingEnabled" = false;
      "SpellCheckServiceEnabled" = false;
      "EnableMediaRouter" = false; # 彻底禁用 Chromecast 相关的 Media Router
      "PasswordManagerEnabled" = true;
    }
  );
in
{
  # TODO: 以下两个模块上游尚未支持 linux 7.x，待修复后启用
  # boot.extraModulePackages = [ config.boot.kernelPackages.lkrg ];  # LKRG: lkrg-1.0.0 不兼容 kernel 7.x (sockaddr_unsized API 变更)
  # "p_lkrg"  # tirdad: 需要 CONFIG_LIVEPATCH=y，且依赖上游修复
  boot.kernelModules = [
    "uinput" # virtual input device, required by kloak
  ];

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
    "kfence.sample_interval=100"
    # 提高 HWRNG 对内核熵池的贡献质量（ANSSI R8）
    "rng_core.default_quality=500"
    # "slub_debug=FZP" 内存分配调试（完整性检查+红区+填毒），开发排查用；生产/游戏负载有 10-20% 开销，暂不启用
  ]
  ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64) [
    "vsyscall=none"
    "efi=disable_early_pci_dma"
    "efi_pstore.pstore_disable=1"
  ];
  boot.kernel.sysctl = {
    # Security (common)
    "kernel.printk_devkmsg" = "off";
    # when '3' can cause steam games stop working
    "kernel.yama.ptrace_scope" = 1;
    "kernel.io_uring_disabled" = 1;
    "dev.tty.legacy_tiocsti" = 0;
    # 开启 SYN Cookies，防御 SYN Flood 洪水攻击
    "net.ipv4.tcp_syncookies" = 1;
    # 开启 RFC1337，防御 TIME-WAIT Assassination 攻击;
    "net.ipv4.tcp_rfc1337" = 1;
    # 记录火星包是安全的，它不丢包，只记日志
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    # 严格模式 (1)，这是安全的默认基线
    # (如果开启了透明代理，proxy.nix 会自动将其覆盖为松散模式 2)
    "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
    "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;
    # 禁止接受 ICMP 重定向 (防止中间人攻击篡改路由表);
    # 普通主机不需要接受重定向，除非充当路由器;
    "net.ipv4.conf.*.accept_redirects" = 0;
    "net.ipv4.conf.*.send_redirects" = 0;
    "net.ipv6.conf.*.accept_redirects" = 0;
    "net.ipv4.conf.*.shared_media" = 0;
    # 禁止源路由 (Source Routing);
    "net.ipv4.conf.*.accept_source_route" = 0;
    "net.ipv6.conf.*.accept_source_route" = 0;
    # ARP 硬化：防止 ARP 缓存中毒和跨接口响应;
    # mkDefault 以便路由角色（router.nix）在多 LAN/网桥/keepalived/proxy-ARP 拓扑下覆盖放松;
    # 端点主机仍取此严格基线，渲染值不变（1/2）。
    "net.ipv4.conf.*.arp_filter" = lib.mkDefault 1;
    "net.ipv4.conf.*.arp_ignore" = lib.mkDefault 2;
    "net.ipv4.conf.*.arp_announce" = 2;
    "net.ipv4.conf.all.drop_gratuitous_arp" = 1;
    # 忽略违规的 ICMP 错误消息;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.conf.all.secure_redirects" = 1;
    "net.ipv4.conf.default.secure_redirects" = 1;
    "net.ipv4.tcp_dsack" = 0;
    "net.ipv4.tcp_fack" = 0;
    # 防止 loopback 地址通过非 loopback 接口路由（ANSSI R12）
    "net.ipv4.conf.all.route_localnet" = 0;
    # 拒绝源地址属于本机接口的入站包，防止反射攻击（ANSSI R12）
    "net.ipv4.conf.all.accept_local" = 0;
    # 临时端口范围收窄，减少端口猜测攻击面（ANSSI R12）
    "net.ipv4.ip_local_port_range" = "32768 65535";
    # IPv6 隐私扩展：生成随机临时地址，保护本机真实 MAC 地址不被追踪;
    "net.ipv6.conf.all.use_tempaddr" = lib.mkDefault 2;
    "net.ipv6.conf.default.use_tempaddr" = lib.mkDefault 2;
    # 增加 BPF JIT 编译器的安全性，消除某些侧信道攻击;
    "net.core.bpf_jit_harden" = 2;
    # 禁止非特权用户调用 eBPF (除非你在进行内核级开发，否则建议开启);
    "kernel.unprivileged_bpf_disabled" = 1;
    # 限制内核指针地址泄露 (防止攻击者探测内核内存布局);
    "kernel.kptr_restrict" = 2;
    # 限制 dmesg 日志访问权限 (防止普通用户查看启动日志中的敏感信息);
    "kernel.dmesg_restrict" = 1;
    # 增加内核崩溃和警告的阈值限制，防止日志泛滥;
    "kernel.oops_limit" = 100;
    "kernel.warn_limit" = 100;
    "kernel.panic" = -1;
    # 核心转储文件处理 (这里设为 piping 给 /bin/false，即直接丢弃);
    "kernel.core_pattern" = "|/bin/false";
    # 禁止加载新的 TTY 线路规程 (减少内核攻击面);
    "dev.tty.ldisc_autoload" = 0;
    # 禁止 kexec (防止在不经过 BIOS 自检的情况下热加载新内核);
    # 注意：这会禁用 kdump 和 systemctl kexec 快速重启功能;
    "kernel.kexec_load_disabled" = 1;
    # 增加 mmap 内存分配的随机性 (ASLR)，增加缓冲区溢出攻击的难度;
    "vm.mmap_rnd_compat_bits" = 16;
    # 强制开启地址空间布局随机化;
    "kernel.randomize_va_space" = 2;
    # 限制性能分析工具 (Perf) 的使用权限;
    # kernel.perf_event_paranoid=2 仅 root 可用 perf；开发者需要剖析时可临时 doas 运行（securix R9）;
    "kernel.perf_event_paranoid" = 2;
    # 限制 perf 最多占用 1% CPU，防止侧信道探测同时不破坏性能分析功能（ANSSI R9）
    "kernel.perf_cpu_time_max_percent" = 1;
    # 限制非特权用户采样速率，进一步阻断计时侧信道（securix R9）
    "kernel.perf_event_max_sample_rate" = 1;
    # kernel.sysrq 已在 core.nix 设为 246（仅启用安全子集，非全量），不再重复定义
    # 禁止程序使用内存最低的 64KB 地址 (防止 NULL 指针解引用攻击);
    "kernel.core_uses_pid" = 1;
    # Core dump 文件名带 PID，防止竞态覆盖攻击
    "vm.mmap_min_addr" = 65536;
    # 限制非特权用户使用 userfaultfd;
    # 注意：极少数高性能虚拟机特性可能依赖此项，一般桌面使用无影响;
    "vm.unprivileged_userfaultfd" = 0;
    # 禁止 SUID 程序在崩溃时产生 Core Dump;
    # 防止特权程序的内存数据（可能含密码）泄露到磁盘;
    "fs.suid_dumpable" = 0;
    # 文件系统链接保护 (防止 /tmp 目录下的竞争条件攻击);
    "fs.protected_regular" = 2;
    "fs.protected_fifos" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
    "vm.mmap_rnd_bits" = 32;
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isAarch64 {
    "vm.mmap_rnd_bits" = 24;
  };
  systemd.coredump.enable = false;
  # 每次启动清理 /tmp 和 /var/tmp，防止上次会话残留的敏感数据（srvos）
  boot.tmp.cleanOnBoot = true;
  # ANSSI R33：审计权限提升与凭证变更事件（不审计 execve，避免桌面/游戏性能损耗）
  # security.auditd.enable = true;
  security.unprivilegedUsernsClone = false;
  environment.memoryAllocator.provider = "graphene-hardened-light"; # balance:scudo performance:mimalloc security:graphene-hardened-light
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
    sudo-rs.enable = false;
    sudo.enable = false;
    doas = {
      enable = true;
      extraRules = [
        {
          groups = [ "wheel" ];
          persist = true;
          keepEnv = true;
        }
      ];
    };
    apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
      packages = [ pkgs.apparmor-profiles ];
    };
  };
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
    networkmanager = {
      wifi.macAddress = lib.mkDefault "random";
      wifi.scanRandMacAddress = lib.mkDefault true;
      # 以太网 MAC 随机化仅对桌面机有意义；服务器固定 MAC 以避免 DHCP 绑定失败
      ethernet.macAddress = lib.mkIf config.services.displayManager.enable (lib.mkDefault "random");
    };
  };
  systemd.services.kloak = lib.mkIf config.i18n.inputMethod.enable {
    description = "Keystroke and mouse timing anonymization";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kloak}/bin/kloak";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
  fileSystems = lib.mkIf config.services.flatpak.enable {
    "/home/${config.mainUser}/.var/app/net.mullvad.MullvadBrowser" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "size=1G"
        "mode=0755"
        "uid=${config.mainUser}"
        "gid=users"
        "nofail"
        "x-systemd.automount"
      ];
    };
  };
  systemd.tmpfiles.rules = lib.mkIf config.services.flatpak.enable [
    "d /etc/brave/policies/managed 0755 root root"
    "C /etc/brave/policies/managed/castration.json 0644 root root - ${bravePolicy}"
  ];
  # ===========================================================================
  #PAM
  security.pam = {
    u2f = {
      enable = lib.mkDefault true;
      settings = {
        cue = true;
        authfile = "/etc/u2f_mappings";
        interactive = true;
      };
    };
    services = {
      doas.u2fAuth = lib.mkDefault true;
      login.u2fAuth = lib.mkDefault true;

      system-login.failDelay.enable = true;
      system-login.failDelay.delay = 4000000;
      passwd.rules.password.unix.settings.rounds = 65536;
      su.requireWheel = true;
    };
  };
  # plug u2f device & use `pamu2fcfg -n`
  environment.etc."u2f_mappings".text = ''
    ${config.mainUser}:8dACAuprRl62N+Nc/J6V8teNz5bkcxosNp5fkvaHse/d3Msfl2w21MOhBMfgcuFD7YnEbuGhJF9kFel58RQRM6xX3e/Okqaxe01DzCa1sBOAD4jUNQzATZfAaRMGtOxuY0Y06JlV/WJzVWrw7MdEd/NBP5RJtFAs8WAaXXdrvOgqzB1CHBGzXwq7ieuX5LzSCnux8ajJI1ksUcaj2viuWNIyTS7N3XjG,I7BP8E3Oc98DkQuND+9J3MPilurDUdwaYdX9nDMuwNZFQoA/DZ1edgl1X9MZOMJoSEfgFr23HaCKzHVy6ulVTg==,es256,+presence
  '';

  # ===========================================================================
  # who can login in THIS machine
  # initialze security key: `ssh-keygen -t ed25519-sk -O resident -O verify-required`
  # add sk: `ssh-add -K`
  # get public key from sk: `ssh-keygen -K`
  # set password: `ssh-keygen -p -f <file name>`
  services.pcscd.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = lib.mkDefault "prohibit-password";
      X11Forwarding = false;
      AllowTcpForwarding = lib.mkDefault "no";
      AllowStreamLocalForwarding = lib.mkDefault false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIORKNKURAriDLXiBpCKeuc3aBcIkQJy32I+sOpwMaWUmAAAABHNzaDo= skKey"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYQdA9KBa2n2xrSk4cr5dYhbLgsUl3vPtc+qjdcIotE ssh-key"
  ];
  # =============================================================================
  # This machine can signing/control key from WHERE?
  programs.git.config = {

    # GIT Signing
    # DISABLE Verified Signing by default
    # non-root User should use `git config --global commit.gpgsign true`
    # signing need user's email dont't foget `git config --global user.email "THE EMAIL"`
    # and add public key for each repo `git config --global user.signingkey "THE PUBLIC KEY"`
    commit.gpgsign = false;
    gpg.format = "ssh";

    # GIT VERIFING
    "gpg \"ssh\"".allowedSignersFile = config.sops.templates."ssh/allowed_signers".path;
  };
  # GIT VERIFING
  sops.templates."ssh/allowed_signers" = {
    content = ''
      # 格式: <email> <public_key>
      24475059+hydroakri@users.noreply.github.com ${skKey}
      24475059+hydroakri@users.noreply.github.com ${bakKey} ${config.sops.placeholder.email}
    '';
    mode = "0444";
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
    '';
  };

}
