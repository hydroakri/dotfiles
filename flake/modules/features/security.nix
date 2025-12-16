{ config, lib, pkgs, ... }:
let
  skKey =
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIF31MN4S2Z4OlWgIXeuacwfUxDcNApQUkcS7kOTwyV3/AAAABHNzaDo= ${config.mainUser}";
  bakKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHf4CJVym33NvIXKx7/W9Ga+Qbp22a86PvelLvjLup3u";
in {
  boot.kernelParams = [
    "mitigations=auto"
    "module.sig_enforce=1"
    "slab_nomerge"
    "page_alloc.shuffle=1"
    "randomize_kstack_offset=on"
    "bdev_allow_write_mounted=0"
    "erst_disable"
    "extra_latent_entropy"
    "hash_pointers=always"
    "iommu=pt"
    "proc_mem.force_override=ptrace"
    "lockdown=integrity"
    # slightly performance loss
    "cfi=kcfi"
    "init_on_alloc=1"
    "random.trust_cpu=0"
    "random.trust_bootloader=0"
  ] ++ lib.optionals (pkgs.stdenv.hostPlatform.isx86_64) [
    "vsyscall=none"
    "efi=disable_early_pci_dma"
    "efi_pstore.pstore_disable=1"
  ];
  boot.kernel.sysctl = {
    # Security (common)
    "kernel.printk_devkmsg" = "off";
    "kernel.yama.ptrace_scope" = 1;
    # 开启 SYN Cookies，防御 SYN Flood 洪水攻击
    "net.ipv4.tcp_syncookies" = 1;
    # 开启 RFC1337，防御 TIME-WAIT Assassination 攻击;
    "net.ipv4.tcp_rfc1337" = 1;
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
    "net.ipv4.conf.*.arp_filter" = 1;
    "net.ipv4.conf.*.arp_ignore" = 2;
    "net.ipv4.conf.all.drop_gratuitous_arp" = 1;
    # 忽略违规的 ICMP 错误消息;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    # IPv6 隐私扩展：生成随机临时地址，保护本机真实 MAC 地址不被追踪;
    "net.ipv6.conf.all.use_tempaddr" = 2;
    "net.ipv6.conf.default.use_tempaddr" = 2;
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
    # 禁止加载新的 TTY 线路规程 (减少内核攻击面);
    "dev.tty.ldisc_autoload" = 0;
    # 禁止 kexec (防止在不经过 BIOS 自检的情况下热加载新内核);
    # 注意：这会禁用 kdump 和 systemctl kexec 快速重启功能;
    "kernel.kexec_load_disabled" = 1;
    # 增加 mmap 内存分配的随机性 (ASLR)，增加缓冲区溢出攻击的难度;
    "vm.mmap_rnd_compat_bits" = 16;
    # 强制开启地址空间布局随机化;
    "kernel.randomize_va_space" = 2;
    # 禁止程序使用内存最低的 64KB 地址 (防止 NULL 指针解引用攻击);
    "vm.mmap_min_addr" = 65536;
    # 限制非特权用户使用 userfaultfd;
    # 注意：极少数高性能虚拟机特性可能依赖此项，一般桌面使用无影响;
    "vm.unprivileged_userfaultfd" = 0;
    # 禁止 SUID 程序在崩溃时产生 Core Dump;
    # 防止特权程序的内存数据（可能含密码）泄露到磁盘;
    "fs.suid_dumpable" = 0;
    # 核心转储文件处理 (这里设为 piping 给 /bin/false，即直接丢弃);
    "kernel.core_pattern" = "|/bin/false";
    # 文件系统链接保护 (防止 /tmp 目录下的竞争条件攻击);
    "fs.protected_regular" = 2;
    "fs.protected_fifos" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    # 限制性能分析工具 (Perf) 的使用权限;
    # 设置为 3 禁止普通用户使用 perf，这是防止提权的有效手段;
    # 开发者如果需要分析性能，请改为 1 或 2;
    "kernel.perf_event_paranoid" = 1;
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
    "vm.mmap_rnd_bits" = 32;
  } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isAarch64 {
    "vm.mmap_rnd_bits" = 24;
  };
  environment.systemPackages = with pkgs; [
    ssh-copy-id
    # keepassxc # installed in flatpak

    # For sops-nix
    age
    sops
    ssh-to-age
    age-plugin-fido2-hmac

    # For fido2 security keys
    pam_u2f
    libfido2
    yubikey-manager
  ];
  security = {
    sudo-rs.enable = true;
    sudo.enable = false;
    apparmor.enable = true;
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  # ===========================================================================
  #PAM
  security.pam = {
    u2f = {
      enable = true; # XXX INSTALLATION: Disable u2f.enable temporarily.
      settings.cue = true;
    };
    services = {
      # XXX INSTALLATION: Disable sudo.u2fAuth, login.u2fAuth temporarily. 
      sudo.u2fAuth = true;
      login.u2fAuth = true;
      sddm.u2fAuth = true;
      cosmic-greeter.u2fAuth = true;
    };
    u2f.settings.authfile = "/etc/u2f_mappings";
  };
  # plug u2f device & use `pamu2fcfg -n`
  environment.etc."u2f_mappings".text = ''
    ${config.mainUser}:8dACAhhnTEKOE88R+/IKyki9JEy+5rinQaCn/Mz/hJppc39O+8lE1X6hCPTQSYGxJqMsdd79r8VR3Sic7S/0goaTACdusvsFwFDenCVc7U6eoMiaSkDf7MoqJaoOh5L7n+I32NeiJnaAXm8Wp8COn8vQY0J6Y9iLUbzWtI9Ugst0bEDbSiOsHK/CWQfK9sf4Df4ONaGvcUFmhgKIyMmRO5aNMTOsqbiEKcRB+vl4kXp8KWzy,ebgHE/SJ/q1P3xk64KI8x560mq76bZJYQtc3YNJoio6zJUkMIXtNvXhcJt9MN2Fu6gB2MWgRsRXQKBZqWmutGg==,es256,+presence
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
      PasswordAuthentication = false; # XXX INSTALLATION: set true temporarily
      KbdInteractiveAuthentication = false;
      PermitRootLogin =
        "prohibit-password"; # XXX INSTALLATION: set "yes" temporarily
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    skKey
    "${bakKey} ${config.sops.placeholder.email}" # 如果你想要那个 email 占位符
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
    "gpg \"ssh\"".allowedSignersFile =
      config.sops.templates."ssh/allowed_signers".path;
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
        ControlPath /tmp/ssh_mux_%u_%C
        ControlPersist 10m

        IdentitiesOnly no # let ssh-agent auto find keys
        # To use specific keys, try `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 user@host`
    '';
  };

}
