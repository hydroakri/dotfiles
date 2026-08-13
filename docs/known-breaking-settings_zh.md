# 已知会造成问题的设置清单（Known Breaking Settings）

本清单记录从上游移植/实验这些内核参数、sysctl、udev 规则时**踩过的坑**——
症状、根因、最终处置和验证方法。它的两个用途：

1. 未来自己踩到类似问题时的速查表
2. 每次从上游搬新设置前的 **check-list**：先对照这张表，别把已知会炸的东西再搬进来

状态图例：`回滚`（试过，否掉了）｜`保留`（带着 workaround 留着）｜`停用`（没启用，等上游修复）｜`未实测`（理论风险）

## A. 启动/系统级风险（最严重）

| 设置 | 症状 | 根因 | 处置 | 来源 | 验证方法 |
|---|---|---|---|---|---|
| `oops=panic` + `kernel.panic=-1` | 任何内核 oops 直接重启；若启动早期 oops 会无限重启循环 | KSPP 标准组合，但配合新内核/新配置有循环风险；`-1` 即"立刻重启" | 保留（KSPP 标配）| `security.nix` / hardened.nix | 上机前必过 CI 构建矩阵；在 oci 先滚一版观察重启稳定性 |
| LKRG（lkrg-1.0.0） | 模块加载失败/不兼容 | lkrg-1.0.0 不兼容 kernel 7.x（`sockaddr_unsized` API 变更） | 停用，等上游支持 | Kicksecure | 每次内核大版本更新后重新验证 |
| tirdad | 无法加载 | 需要 `CONFIG_LIVEPATCH=y`，且依赖上游修复 | 停用 | Kicksecure | 同上 |
| `pcie_aspm=force` + `pcie_port_pm=force` | 潜在的 idle 挂起/设备唤醒异常 | 强制 ASPM 与部分设备电源管理不兼容 | 保留但代码注释标记"出问题先关这两个" | CachyOS | 挂起/唤醒循环测试（`systemctl suspend`→唤醒） |
| amdgpu PSR（`amdgpu.dcfeaturemask=0x8`） | 显示冻结 | Cezanne 上 amdgpu DMCUB 固件在 PSR 开启时崩溃 | 回滚（注释留档） | CachyOS | 显示空闲一段时间后是否冻结 |
| `kernel.kexec_load_disabled=1` | `systemctl kexec` 快速重启、kdump 失效 | 设计如此（防未过 BIOS 自检加载新内核） | 保留（已知代价） | Kicksecure | 无 |
| `amd_iommu=force_isolation` | 开机内核 panic（omen15，第 106 代）；journal 完全没记录——panic 发生在 `systemd-journald` 启动之前 | 强制每设备独立 IOMMU 组；这块主板的 PCIe 拓扑很可能不是每一跳都干净支持 ACS。加之前就注意到内核 6.13 上有过卡启动的报告，但没实测就想当然认为这仓库的 7.1.6 内核大概率已修复 | 已回滚，从 `boot.kernelParams` 删除 | nix-mineral / Kicksecure | 确认是唯一元凶：第 107 代（105 + 仅 `iommu.strict=1` + `lockdown=integrity`，不含 `amd_iommu`）正常开机 |
| `random.trust_cpu=0` + `random.trust_bootloader=0` | 启动阶段熵不足时明显变慢 | 不信 CPU RDRAND/固件熵，等真实熵源 | 保留 | Kicksecure | 对比启动时间 |

## B. 功能损坏级（不影响启动，但会废掉某些软件）

| 设置 | 症状 | 根因 | 处置 | 来源 | 验证方法 |
|---|---|---|---|---|---|
| `kernel.yama.ptrace_scope=3` | Steam 部分游戏停止工作 | 完全禁 ptrace，游戏反作弊/调试器依赖 | 回滚到 1（仅禁非特权用户间 ptrace） | Kicksecure/nix-mineral | 代码注释已记录 |
| `kernel.io_uring_disabled` 桌面设 2 | 一批用户态程序（含部分游戏/并发库）报 io_uring 错误 | io_uring 是主流异步 IO 接口，完全禁掉兼容性差 | 桌面保留 1，服务器块才设 2 | Kicksecure | 桌面跑一轮日常应用 |
| `kernel.perf_event_paranoid=3` | perf/采样工具完全不可用 | 设计如此 | 桌面 2（root 可用），服务器 3 | Kicksecure | 需要 profiling 时发现 |
| `fs.binfmt_misc.status=0`（服务器块） | Wine / binfmt-runner 失效 | 禁 binfmt_misc 是服务器收严项 | 桌面主机不受影响，保留 | Kicksecure | 桌面不动它 |
| `vm.unprivileged_userfaultfd=0` | 极少数高性能虚拟机特性失效 | 禁非特权 userfaultfd | 保留（桌面一般无影响，注释留档） | Kicksecure | 无 |
| `net.ipv4.icmp_echo_ignore_all=1` | ping 不通（对外表现"主机下线"） | 设计如此（防指纹/放大），用 TCP ping 代替 | 保留 | Kicksecure | `tcping`/ssh 连通性 |
| `net.ipv4.conf.all.rp_filter=1`（严格模式） | 透明代理（dae / sing-box TUN）流量被丢弃 | 反向路径过滤太严，代理场景必须松散 | 保留——`proxy.nix` 检测到代理时自动覆盖为 2 | Kicksecure | 开代理后出口流量测试 |
| `net.ipv4.tcp_timestamps=0` | 性能下降（高带宽长连接） | 禁时间戳是安全项，性能上吃亏 | 保留——`performance.nix` 有意覆盖回 1（优先级 900 < 基线 950） | Kicksecure | 带宽测试对比 |
| iwd WiFi 后端 | omen15 无线不稳定/断连 | Realtek 网卡驱动与 iwd 兼容问题 | omen15 覆盖回 `wpa_supplicant`（模块默认仍是 iwd） | 实测 | 长时间挂机测试 |
| `services.openssh.settings` 里的 `DebianBanner=false` | 重建失败，sshd 配置校验拒绝一个不认识的指令 | `DebianBanner` 是 Debian/Ubuntu 专属的 sshd_config 补丁，nixpkgs 原生上游 OpenSSH 没有 | 回滚（手动删除）；`PrintMotd=false` 保留，覆盖同样的横幅抑制意图 | Kicksecure | `nixos-rebuild build` 配置校验失败 |
| `iommu=strict` 内核参数 | 不会导致启动失败，但一直没起到看起来该起的作用 | 不是真实内核参数——通用 IOMMU 层真正的开关是带点号命名空间的 `iommu.strict=1`；`iommu=strict` 被静默当作无法识别的值接受，没有任何效果 | 已修复——换成 `iommu.strict=1` | nix-mineral（`strict-iommu.nix` 里写的就是正确形式） | 第 107 代：`journalctl -k` 显示 "strict mode (set via kernel command line)" |
| `lockdown=confidentiality` 内核参数 | 不会导致启动失败，但压根什么都没做 | 跟 `iommu=strict` 是不同类型的失败——参数名和取值都合法，但这颗仓库自己编的 cachyos-bore-lto 内核从一开始就没编 `CONFIG_SECURITY_LOCKDOWN_LSM`（`/proc/config.gz` 确认：`# CONFIG_SECURITY_LOCKDOWN_LSM is not set`），这个参数配置的整个 LSM 在跑着的内核里根本不存在。另外 NixOS 自己的 `security.lsm`/`security.apparmor` 模块也会显式声明 `lsm=` 启动参数（`landlock,yama,apparmor,bpf`），从来没把 lockdown 列进去——就算真编进内核了，不加进这个列表也不会激活。`/sys/kernel/security/lockdown` 不存在，确认这个 LSM 从没加载过 | 保留，值改正为 `lockdown=integrity`（原来是 `confidentiality`）——现阶段仍然完全无效，但等哪天真的给 `CONFIG_SECURITY_LOCKDOWN_LSM` 打上 Kconfig 补丁，就是对的值不用再改。现在不追——跟 2026-08-11 对内核加固整体定下的"不值这个 Kconfig 维护成本"是同一个判断。`security.nix` 里其他单项设置（`kexec_load_disabled=1`、`debugfs=off`、`nohibernate`）已经覆盖了 lockdown 本该提供的部分保护；它独有的那部分（原始 `/dev/mem`/`/proc/kcore`、MSR 写入、ACPI 表覆盖）目前没有替代 | KSPP / 本仓库自己的 `security.nix` | `cat /sys/kernel/security/lockdown`——这个文件存在才说明 LSM 真的激活了；`/proc/config.gz` 查 Kconfig 符号 |
| `cfi=kcfi` 内核参数 | 不会导致启动失败，静默无效 | `/proc/config.gz` 里 `# CONFIG_CFI is not set`——控制流完整性本身没编进去，即使内核是 clang 编译的（`CONFIG_CC_IS_CLANG=y`，这只是必要条件不是充分条件） | 保留原样，无害死代码——不追（同样是 Kconfig 维护成本的判断） | Kicksecure / KSPP | `zgrep CONFIG_CFI /proc/config.gz` |
| `extra_latent_entropy` 内核参数 | 不会导致启动失败，静默无效 | `/proc/config.gz` 全文搜不到 `CONFIG_LATENT_ENTROPY`/`CONFIG_GCC_PLUGIN_LATENT_ENTROPY` 任何符号。双重不适用：latent_entropy 传统上是 GCC 插件功能，这颗内核是 clang 编译的（`CONFIG_CC_IS_CLANG=y`）——GCC 插件 ABI 跟 clang 工具链压根不兼容 | 保留原样，无害死代码——不追 | KSPP / madaidans-insecurities | `zgrep -i LATENT_ENTROPY /proc/config.gz` |
| `proc_mem.force_override=ptrace` 内核参数 | 不是死代码——是真实生效的覆盖，但方向是变宽松 | `CONFIG_PROC_MEM_ALWAYS_FORCE=y` 是这颗内核编译期的默认值（`/proc/pid/mem` 访问最严格档）；这个启动参数在运行时主动把它降级成 `ptrace` 档。确认是真实生效的运行时覆盖（这类特性的启动参数本来就优先于 Kconfig 默认值），不是 Kconfig 缺口 | 刻意保留在 `ptrace` 档——已知的兼容性考量（某些工具需要在非 ptrace 关系下访问 `/proc/pid/mem`，`always` 档会挡住） | Kicksecure / KSPP | 不适用——这是设计如此，不是 bug；哪天要收紧到 `always` 前先确认那个兼容性需求是否还在 |
| hardened malloc（graphene-hardened-light） | 部分游戏/性能敏感应用掉帧 | 硬化分配器有开销 | 保留；注释留档 scudo（均衡）/mimalloc（性能）备选 | hardened.nix | 游戏帧率对比 |
| `cfi=kcfi` | 整体性能损耗 | 内核 CFI 是复杂度换安全 | 保留（已注明 slightly performance loss） | KSPP | 无 |
| `slub_debug=FZP` | 10-20% 性能开销 | 分配调试（完整性+红区+填毒） | 停用，仅开发排查期临时开 | 实测（注释留档） | 无 |
| earlyoom 误杀 | 游戏/Wine 进程被 OOM 杀掉 | earlyoom 阈值太激进 | 保留——`--avoid (exe|steam|wine|gamescope|mangohud|proton)` | 实测 | 大内存负载下开游戏 |
| kloak 常驻 | niri 全局快捷键、fcitx5 输入法失效 | kloak 独占抓取真实键盘（设计如此） | 保留——不设 wantedBy，手动 `doas systemctl start/stop kloak` | Whonix | 手动启停验证 |
| `vm.swappiness` 高值（180/150） | 无 zram 的机器会过度使用磁盘 swap | 高 swappiness 是为 zram 压缩内存设计的 | 保留——与 `zram-generator` 绑定，禁 zram 必须同时改回 | CachyOS | 看 `zramctl` 是否在跑 |
| zswap 与 zram 共存 | 内存压力表现怪异 | 两个压缩交换栈打架 | 已处理——`zswap.enabled=0` + zram0 初始化后禁 zswap | CachyOS | `zramctl`/`/sys/module/zswap/parameters/enabled` |
| chrony `-F 1`（SCFILTER） | `chronyd` 每次启动都崩溃循环：日志里 "Loaded seccomp filter (level 1)" 刚打出来就 `Main process exited, code=killed, status=31/SYS`，很快撞上 systemd 的 start-limit 放弃重启。2026-08-11 加进去的，2026-08-13 下一次季度复查刚好隔天就发现了 | chrony 的 `-F` seccomp 过滤器是针对标准 glibc + glibc malloc 编译出来的 `chronyd` 生成的系统调用白名单。本仓库 `services.chrony.package = pkgs.pkgsMusl.chrony` 同时链接了 musl libc *和* `libhardened_malloc-light.so`（`ldd` 确认）——两者都会改变正常操作实际发出的底层系统调用，导致某个本来合法的调用落在编译期白名单之外，被内核直接杀掉 | 已回滚——从 `extraFlags` 删掉 `-F 1`，保留不受影响的 `-r`（复用历史测量数据） | chrony 自身特性，2026-08-11 复查引入 | `journalctl -u chronyd`：SIGSYS 紧跟在 seccomp filter 加载日志后面就是特征；想复现的话在继续用 `pkgsMusl.chrony` 的前提下把 `-F 1` 加回去 |
| `preservation.preserveAt` 目录条目没显式写 `user`/`group`/`mode` | 线上 `/var/lib/chrony` 实际是 `0755 root:root`（`stat` 确认），而不是 NixOS chrony 模块自己在 `00-nixos.conf` 里设的 `0750 chrony:chrony`——chrony（只在 `chrony` 组，不在 `root` 组）落进这权限的 "other" 档：只有读+执行，没有写，导致它在自己的状态目录里建不了新文件（已有的、chrony 自己拥有的文件还能正常写）。是排查上面那条 `-F 1` 崩溃时顺带发现的 | `preservation` flake 模块（`nix-community/preservation`）默认每条 `directories` 都是 `user=root group=root mode="0755"`，除非单独覆盖。`/etc/tmpfiles.d/` 里 `preservation.conf` 按字母序排在 `00-nixos.conf` 后面（`p` > `0`），它的 `d` 行后跑、后写，把模块自己的加固默认值悄悄覆盖掉了。`unbound.service` 没这问题，因为它声明了 `StateDirectory=unbound`，systemd 每次启动服务都会重新校正——chrony 没有这个声明，tmpfiles 跑完之后没人再修 | 已修复——在 `preservation.nix` 里给 `/var/lib/chrony` 这条显式加上 `user = "chrony"; group = "chrony"; mode = "0750";`，对齐回 NixOS 模块自己的默认值。把列表里其它条目也挨个查了一遍同类问题：`bluetooth`/`power-profiles-daemon`/`upower`/`cloudflare-warp`/`fwupd-refresh` 都靠自己的 `StateDirectory=` 自我校正；`NetworkManager`/`nbfc_service` 本来就是以 root 身份跑的，`0755 root:root` 默认值正好对得上。chrony 是唯一真正踩坑的 | 本仓库自己的 `preservation.nix` vs. `nix-community/preservation` 的默认值 | 上线后 `stat -c "%a %U:%G" /var/lib/chrony` 应该是 `750 chrony:chrony`；别默认假设列表里其它没有 `StateDirectory=` 的服务就没事，得挨个查 |

## C. 上游模块与内核版本打架

| 现象 | 根因 | 处置 |
|---|---|---|
| 模块 meta.broken：跟不上锁定内核版本 | 上游模块（如 LKRG、tirdad）对新内核 API 支持滞后 | 升级内核前先查对应上游是否支持（见 `hosts/isolive/isolive.nix` 注释）；CI 会挡掉 build 失败 |

## 实验纪律（怎么避免"机器起不来"）

1. 默认滚动顺序：**oci → rpi → omen15**（服务器炸了损失最小，主力笔记本最后上）
2. 直连机器上：NixOS 有 generation 回滚兜底（`nixos-rebuild list-generations` + 开机引导菜单选旧 generation），但**只有换掉崩溃参数的那一代才能救回来**——所以一次只改一个设置组
3. 远程机器（oci/rpi）：先 `nixos-rebuild build`（不 activate），确认 build 通过再 switch；换内核参数这类启动期设置时，准备好 rescue 手段（Oracle Cloud 的 VNC/console、rpi 的串口）
4. 新设置上机前先在 `nix flake check` + CI 构建矩阵过一遍（它们不启动系统，但能挡掉拼写/类型错误）