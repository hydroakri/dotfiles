# 上游设置溯源表（Upstream Settings Provenance）

本仓库 `flake/modules/features/` 下的内核参数 / sysctl / udev / modprobe 硬化
**改编而非照抄**自多个上游发行版（见 README「Reference Sources」）。本表记录
每一个设置组的出处、移植状态和复查时间，是季度复查（见文末流程）的对照基准。

## 状态图例

| 状态 | 含义 |
|---|---|
| `已移植` | 已进入本仓库模块，且经过至少一台主机实测 |
| `部分移植` | 只取了该上游的某几项设置 |
| `仅参考` | 还没动手移植，只作为思路/对照来源 |
| `实验中被否` | 试过但出了问题，详见 `known-breaking-settings_zh.md` |

## 溯源表

| 设置组 | 上游出处 | 本仓库位置 | 状态 | 最近复查 |
|---|---|---|---|---|
| 基础 sysctl 基线（kernel.* 指针/dmesg/bpf、net.* ARP/ICMP/重定向、fs.protected_* 等） | Kicksecure `security-misc` 的 `/usr/lib/sysctl.d/990-security-misc.conf`（KSPP 推荐基线）+ ANSSI 指南（注释中 R8/R9/R12/R33） | `security.nix` 950 优先级块 | 已移植（改：合并了 ANSSI 项、`ptrace_scope` 降到 1、`io_uring_disabled` 桌面留 1） | 2026-08-12 |
| 内核启动参数（slab_nomerge、lockdown、cfi、init_on_alloc、oops=panic…） | KSPP / nixpkgs `hardened.nix` / madaidans-insecurities（nix-mineral 同源思路） | `security.nix` `boot.kernelParams` | 已移植（2026-08-12：修复 `iommu=strict`→`iommu.strict=1` 的 bug；`amd_iommu=force_isolation` 试过导致开机内核 panic，已回滚——见 `known-breaking-settings.md`） | 2026-08-12 |
| 服务器严格模式块（io_uring/perf/binfmt_misc 全禁） | Kicksecure `security-misc`（server 变体）+ 自研按有无显示服务器区分 | `security.nix` 900 优先级块 | 已移植 | 2026-08-12 |
| I/O 调度器 udev 规则（kyber/mq-deadline/bfq）、hdparm -B 254 -S 0、cpu_dma_latency 属组 audio | CachyOS `CachyOS-Settings` `usr/lib/udev/rules.d/60-ioschedulers.rules` | `performance.nix` `services.udev.extraRules` | 已移植（规则原文改编；`40-hpet-permissions.rules`/`50-sata.rules` 2026-08-12 一并移植，`71-nvidia.rules` 移进 `nvidia.nix`） | 2026-08-12 |
| 性能 sysctl（dirty_bytes、vfs_cache_pressure、page-cluster、watermark、min_free_kbytes…） | CachyOS `CachyOS-Settings` `usr/lib/sysctl.d/70-cachyos-settings.conf` | `performance.nix` `boot.kernel.sysctl`（vm.* 块） | 已移植（swappiness 改为 180、补 watermark/compaction 等） | 2026-08-12 |
| BBR + CAKE qdisc、TCP 缓冲调参 | CachyOS / 通用网络调优（Fq_codel 系） | `performance.nix` net.* 块 | 已移植 | 2026-08-12 |
| ananicy 进程优先级 + cachyos 规则集 | CachyOS（ananicy-cpp + ananicy-rules-cachyos） | `performance.nix` `services.ananicy` | 已移植（活的 nixpkgs 依赖，不是静态快照——自动跟上游同步） | 2026-08-12 |
| zram-generator（ram/2, zstd）+ zswap 禁用 | CachyOS 默认（systemd-zram-generator + CachyOS-Settings 联动） | `performance.nix` | 已移植 | 2026-08-12 |
| scx 调度器（scx_rusty） | CachyOS `linux-cachyos`（sched-ext 系） | `performance.nix` `services.scx` | 已移植（无法 diff——`linux-cachyos` 不在已 vendor 的 `CachyOS-Settings` 快照里） | 2026-08-12 |
| snd-hda-intel AC/电池电源管理 udev | CachyOS `CachyOS-Settings` udev 规则 | `powersave.nix` | 已移植（确认与上游相比是刻意简化——写死数值取代捕获默认值再还原） | 2026-08-12 |
| PCIe ASPM 策略、amd_pstate=active、teo governor | CachyOS / TLP 思路（自研 udev 脚本） | `powersave.nix` | 已移植（确认自研——已 vendor 的 `cachyos` 快照里没有对应文件） | 2026-08-12 |
| kloak（击键/鼠标时序匿名化） | Whonix / kloak 上游（nixpkgs 只有二进制） | `privacy.nix` | 部分移植（自写 systemd 单元 + Wayland 探测） | 无法复查（kloak 上游不在 8 个已 vendor 来源之列） |
| IPv6 隐私地址、MAC 随机化 | 通用基线（Kicksecure 网络硬化亦有） | `privacy.nix` | 已移植 | 2026-08-12 |
| Unbound 解析器硬化（hide-identity/hide-version、aggressive-nsec、harden-large-queries、use-caps-for-id、private-address 反 DNS rebinding） | OpenBSD `etc/unbound.conf`（基础结构）+ secureblue `unbound/conf.d`（harden-large-queries/use-caps-for-id）+ GrapheneOS `infrastructure` `etc/unbound/unbound.conf`（tls-cert-bundle/private-address） | `core.nix` `services.unbound.settings.server` | 已移植 | 2026-08-12 |
| DoT forward-zone：单一还是多家上游 | secureblue 的 `dnsconfd`/`dns_selector.py` 只选一家（+同厂商备援 IP） | `privacy.nix` `forward-zone` | 仅参考——维持现有 5 家 | 2026-08-12 |
| 内核模块黑名单 | Kicksecure `security-misc`（蓝牙等）→ nix-mineral 亦有 | 未移植（当前只禁了必要项） | 仅参考 | 2026-08-12 |
| sysctl 全套逐项对照 | nix-mineral、secureblue、Bazzite | `docs/upstream-vendor/diff_sysctl.py`——自动逐项对比本仓库声明的 sysctl,不代表对任何一项做了取舍决定。已知盲区：只扫描 `flake/modules/features/*.nix`，漏掉 `desktop.nix`/`server.nix` | 仅参考(工具) | 2026-08-13 |
| 内核 Kconfig 硬化 | Pop!_OS `linux`、Qubes `qubes-linux-kernel`、Kicksecure `hardened-kernel`、KSPP 推荐项一般性参考 | — | 不追踪(2026-08-11 移除:本仓库自己编译 CachyOS 内核,任何 Kconfig 发现都要靠维护内核补丁/`structuredExtraConfig` 才能落地,不是改一行 Nix 那么简单,维护成本不划算) | — |
| AppArmor profile 集 | Tails `config/`(AppArmor 硬化) | `security.nix` 只启用了 nixpkgs 自带 profiles | 仅参考——Tails 现为第 9 个已 vendor 来源，已复查；大部分是 Tor/onionshare/Debian FHS 专属，不可移植。`attach_disconnected`（与 `preservation.nix` bind mount 相关）试过又撤回——见复查记录 | 2026-08-12 |
| 内核 config 级硬化 | Pop!_OS `linux` / Qubes `qubes-linux-kernel` / Kicksecure `hardened-kernel` | 未移植(NixOS 内核 config 改造是独立项目;已自动化的部分见上面 Kconfig 检查) | 仅参考 | — |
| secureblue 全套(dconf/sysctl/udev) | `secureblue/secureblue` | sysctl:已自动 diff(见上)。udev:`50-usb-realtek-net.rules` 试过又撤回（`performance.nix`），U2F 改用 `services.udev.packages=[pkgs.libfido2]` 而非搬 `70-u2f.rules`，`51-android.rules` 不采纳（nixpkgs 判定被 systemd uaccess 取代）。dconf:不适用（跑 niri，不是 GNOME） | 仅参考 | 2026-08-13 |
| Bazzite 桌面/游戏向 sysctl + udev | `ublue-os/bazzite` `system_files/desktop/shared` | sysctl:已自动 diff(见上)。udev:2026-08-12 已人工复核，非硬件专属项已无遗留 | 仅参考 | 2026-08-13 |
| srvos(boot.tmp.cleanOnBoot 等) | nix-community/srvos | `security.nix` 个别行 | 部分移植（不是 flake input——一次性手动改编的参考，没有活的来源可以 diff） | 2026-08-12 |

## 复查记录

一行一个决定。已 vendor 的来源:CachyOS、Kicksecure、secureblue、Bazzite、
nix-mineral、Pop!_OS `default-settings`、GrapheneOS `infrastructure`、
OpenBSD、Tails(共 9 个)。过程/工具类记录(修的 bug、查过但没结果的来源、覆盖面
方法论)放在 `docs/upstream-vendor/README.md`,这里不重复。

### 2026-08-11

| 项目 | 取舍理由 |
|---|---|
| `net.core.netdev_max_backlog` 2048 → 4096 | 纯缓冲区大小,现代内存下无代价 |
| `fs.inotify.max_user_instances` 1024 → 8192 | 开发工具/游戏常吃满默认值,代价可忽略 |
| `vm.mmap_rnd_bits` 不变 | 工具误报——按架构条件分支(x86_64=32/aarch64=24),omen15 本来就是 32 |
| `kernel.oops_limit`/`warn_limit` 保留 100 | nix-mineral 的 1 太激进,日常驱动小故障就会重启机器 |
| `kernel.yama.ptrace_scope` 保留 1 | 3 会破坏 Steam(已记录);GrapheneOS 的 2 没实测过,不值得冒险 |
| `vm.swappiness` 保留 180 | 跟 zram-generator 容量绑定 |
| `net.ipv4.tcp_sack` 保留开 | 促使关闭的 CVE 早在 2019 年修了,现在关只剩性能代价 |
| `net.ipv4.tcp_tw_reuse` 保留开 | 配合已开启的 tcp_timestamps 是安全的;NAT 冲突场景对单用户客户端不适用 |
| `net.ipv6.conf.*.accept_ra` 保留 2 | rpi4-switch 靠它拿 IPv6 前缀委派;为了未经验证的收益冒断路由器 IPv6 的风险不值得 |
| `vm.dirty_background_bytes` 保留 128MB | Bazzite + Pop!_OS(场景更接近)都认同 |
| `vm.max_map_count` 1048576 → 2147483642 | Bazzite **和** Pop!_OS 都默认这个值(不是游戏专属);软上限,无预占代价 |
| `net.ipv4.ip_forward`/ipv6 forwarding 不变 | 本来就只在 router.nix 里生效,不是全局设置 |
| `services.usbguard.presentDevicePolicy` `keep` → `allow` | 匹配 Kicksecure 默认值 |
| `services.usbguard.IPCAllowedGroups` 不变(空) | `IPCAllowedUsers` 已经覆盖主用户 |
| `PermitRootLogin` 保留 `prohibit-password` | 已经仅密钥登录;彻底禁用有切断未确认的 root SSH 流程的风险 |
| journald `SystemMaxUse` 保留 64M | 纯磁盘占用/保留时长取舍,不涉及安全 |
| SSH 服务端加密算法(`Ciphers`/`KexAlgorithms` 收窄,`HostKeyAlgorithms`/`PubkeyAcceptedAlgorithms` 仅 ed25519,`HostKey` 限制) | Kicksecure sshd_config.d;`Macs` 故意不声明——NixOS 自带精选默认值已经一致 |
| SSH 服务端会话/banner 加固(`AllowAgentForwarding`/`Compression`/`TCPKeepAlive`=false、`MaxAuthTries`/`MaxSessions`/`ClientAliveCountMax`、`DebianBanner`/`PrintMotd`=false、`UsePAM`=true) | 单用户机器上代价极低或没有 |
| SSH 客户端同步服务端加密算法 + `VisualHostKey=yes` | 与服务端同样的理由 |
| `security.pam.loginLimits` coredump=0 + memlock≈2GB(新增) | 配合已有的禁 coredump;让 GPG/密码管理器能锁内存不被换出 |
| `@audio` 实时优先级 ulimit 不采纳 | `security.rtkit.enable`(已开)是更现代的按进程方案,带看门狗 |
| `systemd.tmpfiles.rules` THP 调优(新增) | 跟已有的 `transparent_hugepage=madvise` 不重复——那个管"要不要用",这个管"怎么分配" |
| DMI `product_serial` 权限收紧到 root/wheel(新增) | 设备指纹向量,无功能代价 |
| `DefaultLimitNOFILE` 调高(系统+用户,新增) | 跟 inotify 那次同样的"开发工具/游戏吃满默认值"理由 |
| `DumpCore=false`(系统+用户,新增) | 跟已有的全面禁 coredump 立场一致 |
| `DefaultTimeoutStartSec`/`StopSec` 保留 90s | 没理由为了收紧去冒误杀慢启动服务的风险 |
| pstore `Storage=none`(新增) | 呼应已有的 `erst_disable` 内核参数 |
| NetworkManager `ipv6.ip6-privacy=2`(新增) | 防一个已知的 NM 版本 bug——全局 sysctl 继承有时不可靠 |
| `main.dns=dnsconfd` 不采纳 | Fedora/rpm-ostree 专属,NixOS 用不了 |
| resolved `LLMNR=false` 不采纳 | 不适用——`services.resolved.enable` 默认关且这里从没开过 |
| `boot.blacklistedKernelModules`,769 个模块(新增) | 老旧/冷门硬件(DVB 电视卡、老 framebuffer、gameport 摇杆、FireWire、RDMA、冷门网络协议、`evbug`、易被 fuzz 出洞的冷门文件系统)——有攻击面但这里用不上 |
| 黑名单明确排除:CAN、NFS/CIFS、Thunderbolt、蓝牙(`bluetooth`/`btusb`)、`joydev`、RNDIS | 每一个在这台机器上都有说得通的真实用途(NAS 挂载、外接 GPU/底座、蓝牙外设、现代手柄走老 API、手机 USB 捷网) |
| `nf_conntrack_helper=0`(新增) | 标准加固项,无功能代价 |
| chrony `minsources` → 2(问过 3) | 7 个配置源的前提下不用太严也能保证多源一致 |
| chrony `authselectmode prefer`(新增) | 优先用 NTS 源;两次(secureblue 版和 GrapheneOS 版)都在更严格的 `require` 面前选了这个,因为有一个配的源不是 NTS |
| chrony `dscp`/`dumpdir`/`leapseclist`/`rtcsync` 打包(新增) | 低风险的运维/精度改善 |
| chrony 新增 3 个 NTS 服务器(新增) | 加之前确认过跟其余部分同属 secureblue 出处,不是混搭 |
| chrony `cmdport 0` 不采纳 | 会让本地 `chronyc` 诊断工具用不了 |
| chrony `enableRTCTrimming=false`(新增,必须) | 跟上面的 `rtcsync` 冲突——两个都开 NixOS 直接拒绝构建 |
| chrony `extraFlags` seccomp + 历史重载(新增) | chrony 成熟稳定的老功能,风险低 |
| `zram-generator` 容量封顶 16GB(新增) | 大内存机器上超过这个数边际收益递减 |
| 蓝牙守护进程加固打包(限时、`MaxControllers`、`Privacy=network/on`、`AutoEnable=false`、`powerOnBoot=false`) | 驱动继续保留(见上面黑名单那条);这是在保留功能前提下收紧守护进程行为,无功能损失 |
| `faillock.conf`/`pwquality.conf` 不采纳 | 这里靠密钥认证不是密码;`pwquality` 连上游自己都设了 `enforcing=0` |
| `access.conf`(仅 console 登录)不采纳 | 公共/共享终端的威胁模型,不是个人笔记本的 |
| `gpg.conf` 采纳进 `dot_gnupg/`(chezmoi,不进 flake) | 每用户应用配置不是系统策略;虽然日常不用 GPG 但先放着不吃亏 |
| `kyber-iosched` 加进 `boot.kernelModules`(新增) | 已有的 udev 规则给 NVMe 盘指定这个调度器,没模块可能一直静默失效 |
| `boot.kernelParams "nohibernate"`(新增) | 休眠这里本来就用不了(`lockdown=confidentiality` + zram);顺手显式声明不吃亏 |
| bpf_jit_enable/redirect+martian+rp_filter sysctl/AppArmor/`unprivilegedUsernsClone`/`allowed-users`——不是缺口 | 已经被现有更精细或等价/更严格的设置覆盖 |
| `kernel.ftrace_enabled=false` 不采纳 | 会废掉 perf/追踪工具;perf 的访问已经靠 perf_event_paranoid 管着 |
| `page_poison=1` 不采纳 | 内核开发调试用途,真实性能代价换来的终端用户收益有限 |
| `security.lockKernelModules=true` 不采纳 | 会打断开机后加载驱动的场景,跟这轮其余的设备兼容性判断一致 |
| `nosmt` 不采纳 | 对性能调优机器代价巨大,防的是 NixOS 自己文档都说"未经证实"的攻击 |
| `pti=on`(强制 KPTI)不采纳 | 对已免疫 Meltdown 的现代 CPU 零收益,跟已有的 `mitigations=auto` 冲突 |
| `flushL1DataCache` 暂不适用 | 只有当 hypervisor 才相关;`libvirtd` 现在是关的 |
| 逐服务 systemd 沙箱化(`ProtectSystem` 等)延后 | 结构不同的另一个维度(逐服务而非系统级),体量够独立开一轮 |
| `net.mptcp.enabled=0`(新增) | 这台桌面机用不到的协议,少一个解析器就少一分攻击面 |
| `vm.memfd_noexec=1`(新增) | 现代反无文件恶意代码缓解措施,主流发行版正在收敛到这个默认值 |

### 2026-08-12

| 项目 | 取舍理由 |
|---|---|
| `do-ip6` 保留 `true` | 跟 OpenBSD 默认一致;避免 IPv6 `forward-addr` 变成死配置 |
| `harden-large-queries`/`use-caps-for-id`(新增） | secureblue 基线;纯 TLS 转发下几乎零代价 |
| `private-address` 反 DNS rebinding(新增,全部 host） | GrapheneOS `infrastructure`;只过滤上游返回的答案,不影响 host 自身网卡绑定 |
| `tls-cert-bundle` 显式写不采纳 | nixpkgs 的 `unbound.nix` 模块本来就 `mkDefault config.security.pki.caBundle` |
| DoT forward-zone 维持 5 家 | secureblue 只选一家;这里更看重多样性,接受多一点第三方看到查询片段 |
| OpenBSD 加为第 8 个 vendor 来源(`etc/` 稀疏检出） | vendor 集里唯一一份真实手写的 `unbound.conf`;完整 `src` 约 1.6GB |

### 2026-08-12（续：`diff_sysctl.py`/`diff_misc.py` 全量扫描 + udev/systemd 服务人工复核）

说明：`grapheneos-infra` 是 GrapheneOS **自己运营的服务器**基础设施
（`github.com/GrapheneOS/infrastructure`——attestation/app 仓库/更新服务器
等后端），不是 Android 手机端配置。下表引用它的行按此理解;本轮复查早期
草稿曾把其中一部分误标为手机/终端设备调优。

| 项目 | 取舍理由 |
|---|---|
| `kernel.watchdog=0`(新增,`powersave.nix`） | 与已有的 `kernel.nmi_watchdog=0` 同一意图；bazzite |
| `net.ipv4.conf.default.drop_gratuitous_arp=1`(新增） | `.all.` 已设,`.default.` 是相邻 `log_martians`/`rp_filter` 成对设计里的缺口；nix-mineral |
| `net.ipv6.icmp.echo_ignore_{anycast,multicast}=1`(新增,全局） | 补齐已有的全面禁 ping 姿态（两个 `icmp_echo_ignore_all` 早已设好）；不影响 NDP（用 type 135/136,不是 echo）；nix-mineral |
| `abi.vsyscall32=0`(新增,标记待验证） | 与已在跑的 `vsyscall=none` 同类（无 Steam 故障记录）；范围更窄,标记为需要真实测试才能算尘埃落定 |
| `kernel.unprivileged_userns_clone=1`(新增,显式固定）+ 删除 `security.unprivilegedUsernsClone=lib.mkDefault false` | 那个 NixOS 选项只在 `true` 时才会去设 sysctl,为 `false` 时什么都不做——死代码/误导。真实值原本靠内核自带默认（omen15 的 cachyos-bore-lto 内核实测为 `1`）；podman 需要它,现在显式固定 |
| `net.ipv4.tcp_shrink_window=1`(新增,`performance.nix`） | 内存压力下收缩接收窗口,无观察到的下行 |
| `NVreg_EnableS0ixPowerManagement=1`(新增,`nvidia.nix`） | omen15 实测 `/sys/power/mem_sleep` 为 `[s2idle] deep`——GPU 确实走 S0ix；bazzite |
| `71-nvidia.rules` 只加 unbind→`on` 还原部分(新增,`nvidia.nix`） | bind→`auto` 那半已经被 `powersave.nix` 的通用规则 `SUBSYSTEM=="pci", ATTR{power/control}="auto"` 覆盖；只有 unbind 还原方向是真缺口；cachyos |
| `journald.ForwardToWall=no`(新增） | 只阻止 emerg 级消息 wall 广播到其他终端,不影响 `journalctl`/日志内容；Kicksecure |
| `journald.Storage=persistent`(新增） | 原来是 `auto`；强制日志落盘并跨重启保留；Kicksecure |
| `usbguard.implicitPolicyTarget=block`/`presentControllerPolicy=keep`/`deviceRulesWithPort=false`(新增） | Kicksecure 默认值；NixOS 模块把这几个暴露为真实可设的选项 |
| `usbguard.AuthorizedDefault`/`HidePII` 不采纳 | NixOS 的 `services.usbguard` 模块是封闭的手工拼接配置,没有透传接口——这两个键根本不存在；想加就得完全绕开模块（自写 `ExecStart`）,为两个大概率本来就是默认值的开关不值得 |
| `rescue.service`/`emergency.service` 的 `SYSTEMD_SULOGIN_FORCE=1`(新增） | rescue/emergency 模式强制要求 root 密码,而不是直接掉进未认证的 root shell；Kicksecure |
| `-.slice` 的 `MemoryLow`/`MemoryMin=64M`(新增） | 不是 NixOS 默认行为（只有开 `systemd-oomd` 才会设）——纯内存 cgroup 保底,不依赖 oomd；grapheneos-infra |
| `sshd` 的 `LimitNOFILE=8192` + 带退避的 `Restart=always`(新增） | 低风险；去掉了 grapheneos-infra 的 `ManagedOOMPreference=avoid`,因为这里 `systemd.oomd.enable=false` |
| `fstrim` 的 `interval=daily` + idle CPU/IO 调度(新增） | 原来是 `weekly`,NixOS 和 util-linux 自带单元都没设调度优先级；grapheneos-infra |
| `unbound.service` 只加 `Restart=always` 带退避(新增） | secureblue 的额外沙箱（`ProtectSystem=strict` 等）不采纳——NixOS 自己的 `unbound.nix` 模块已经持平或更严格；只有重启退避（grapheneos-infra）是真缺口 |
| `40-hpet-permissions.rules`(新增,`performance.nix`） | `rtc0`/`hpet` 归属 `audio` 组；和已采纳的 `cpu_dma_latency`→`audio` 风险等级一致；cachyos |
| `50-sata.rules` ALPM `max_performance`(新增,`performance.nix`） | 匹配条件自限定（`link_power_management_supported=="1"`）；omen15 内部无 SATA（纯 NVMe,`lsblk` 实测确认）,但有在用 USB-SATA 外接机械硬盘——两种情况都无下行 |
| `50-usb-realtek-net.rules`——试过,已撤回 | 为一个设备背 24 个厂商 ID 不值得；secureblue |
| U2F/FIDO 改用 `services.udev.packages = [ pkgs.libfido2 ]`(新增）取代手抄 secureblue 的 `70-u2f.rules` | `libfido2` 早就在 `environment.systemPackages` 里,但自带的 udev 规则从未被注册启用——用官方维护的包规则,而不是搬 secureblue 的快照 |
| `51-android.rules` 不采纳 | nixpkgs 自己移除了 `android-udev-rules` 包："已被 systemd 内置 uaccess 规则取代" |
| `titan-key.rules` 里额外的 Feitian 代工 ID(`096e:0858`/`085b`）不采纳 | 确认是 Google 自家版（`18d1:5026`）,已被 `libfido2` 自带规则覆盖 |
| `server.nix`：`tcp_ecn=0`/`tcp_syn_retries=4`/`tcp_synack_retries=3`/`tcp_orphan_retries=6`/`tcp_retries2=8`(新增） | 服务器自保,防半开连接耗尽资源；对口场景是 `oci`（nginx 反代 headscale/vaultwarden/searx/atticd/ntfy-sh 等,对外暴露 80/443）——同样作用于 `rpi4-switch`/`rpi4-side-gateway`,因为它们同样 import `server.nix`；grapheneos-infra |
| `server.nix`：`tcp_fin_timeout=30`/`tcp_notsent_lowat=131072`/`nf_conntrack_tcp_timeout_established=1800`,`mkOverride 900`(新增） | 容纳 `oci` 上大量/不稳定的外部客户端连接；grapheneos-infra。`ip_local_port_range` 不覆盖——ANSSI 收窄攻击面优先于服务器端口容量 |
| `server.nix` 现有的 `netdev_max_backlog`/`rmem_max`/`wmem_max`/`tcp_rmem`/`tcp_wmem`/`tcp_mem`(`mkDefault`）保留原样,加注释 | 既有死代码,实际 6 行不是最初标的 5 行（第一遍漏了 `netdev_max_backlog`）——全部被 `performance.nix` 的 `mkOverride 950` 打败,从未生效过。`oci` 现在的流量级别没有强理由需要更小的值；保留但不提优先级,不悄悄删掉 |
| GrapheneOS conntrack/缓冲区集群在桌面/路由场景不采纳（`net.core.rmem_max` 调小、`ip_local_port_range` 放宽等作为整体改动） | 工作负载不匹配,`omen15`/`rpi4-*` 在上面 `server.nix` 相关行覆盖范围之外 |
| `kernel.sysrq=0` 不采纳 | `core.nix` 已经设了 `kernel.sysrq=246`——是 curated 过的安全子集,不是内核默认值；不是 Kicksecure/secureblue 那种非黑即白的开关 |
| `dev.cdrom.*=0` 不采纳 | 没有光驱硬件 |
| `kernel.io_uring_group`/`net.core.devconf_inherit_init_net`/`dev.raid.speed_limit_{max,min}` 不采纳 | 没有按 gid 隔离 io_uring 的场景,没有匹配的 netns/容器化部署,全仓库没有 mdadm RAID |
| `amdgpu`/`radeon` 的 `si_support`/`cik_support` 不采纳 | 针对 2012–2014 年代 GCN 1.0/2.x 显卡；硬件代次不对 |
| grapheneos-infra 的 `modules-load.d` 集(`bonding`/`dm_crypt`/`nft_*`/`sch_fq`/`softdog`/`veth`/`vfat`）不采纳 | 没有绑定网卡,没有 LUKS,没有真正的 `nftables` 规则集（`networking.nftables.enable` 是 `false`）；`softdog` 与已有的 `nowatchdog`+`nmi_watchdog=0` 直接冲突；`veth`/`vfat` 按需自动加载即可,预加载收益低 |
| `libno_rlimit_as.so` 不采纳 | 没有现成 NixOS 包；为 hardened malloc 的配套 shim 自行打包成本不成比例 |
| `systemd-boot-update.service` 的 `SYSTEMD_RELAX_ESP_CHECKS=1` 不采纳 | GrapheneOS 特定 OEM 场景的 ESP 校验变通；这里没有对应问题 |
| `85-iw-regulatory.rules` + 配套 service 整套不采纳 | 根据时区自动推断 WiFi 监管国家；`core.nix` 硬编码 `time.timeZone="UTC"`,脚本自己在 UTC 下就会跳过设置——被一个既有的刻意设置永久失效 |
| `95-emerg-shutdown.rules` + `emerg-shutdown.service` 整套不采纳 | 启动介质被拔出时强制关机,针对便携/live-USB 安装（类 Tails 反取证场景）；四台主机都不是便携安装 |
| Tails 的 `attach_disconnected` AppArmor 标志（通过 `apparmor-profiles.overrideAttrs`）——试过又撤回 | nixpkgs 自己的 profile 集对这个标志维护着按 profile 例外名单；无差别全加会撤掉一层真实的防命名空间逃逸防护。推迟到真的出现 `preservation.nix` 触发的拒绝记录再处理 |
| `DebianBanner=false` 不补 | Debian 专属 sshd_config 补丁,nixpkgs 原生 OpenSSH 没有——见 `known-breaking-settings.md` |
| `kernel.printk="3 3 3 3"` 迁到 `security.nix` 不采纳 | 留在 `desktop.nix`,和安静开机/plymouth UX 绑在一起；`oci`/`rpi4-*`（`server.nix`）仍然没有这条——已知缺口,本轮未修 |
| tmpfiles/coredump 重叠项（secureblue 的 3 天清理规则、`coredump.conf.d Storage=none`）——仅记录,不改配置 | 已经三重禁止 coredump（`core_pattern`/`DumpCore=false`/ulimit `core=0`）；这两条大概率是无用功 |
| `diff_sysctl.py` 盲区记录（见 `docs/upstream-vendor/README.md`） | 只扫描 `flake/modules/features/*.nix`；漏掉 `desktop.nix`/`server.nix`,这也是 `kernel.printk` 被误报"not ported"的原因（其实设在 `desktop.nix`） |

### 2026-08-12（续：`boot.kernelParams` 人工复查——`diff_sysctl.py` 只解析 `key = value` 形式的 sysctl,碰不到这块）

| 项目 | 取舍理由 |
|---|---|
| `iommu=strict` → `iommu.strict=1`（修 bug） | `iommu=strict` 不是真实内核参数,通用 IOMMU 层的开关是带点号命名空间的。`dmesg` 实测确认过修复前是 `iommu: DMA domain TLB invalidation policy: lazy mode`——这行从加进去那天起就没生效过。详见 `known-breaking-settings.md` |
| `amd_iommu=force_isolation`——试过,开机内核 panic,已回滚 | 见 `known-breaking-settings.md` |
| `init_on_free=1` 不采纳 | 配套 `init_on_alloc=1`，代价翻倍，不值得 |
| `hardened_usercopy=1` 不采纳 | 无效——`CONFIG_HARDENED_USERCOPY_DEFAULT_ON=y` 已开 |
| Kicksecure 的逐 CVE 显式缓解系列（`spectre_v2=on`、`l1tf=*`、`kvm-intel.*`、`mds=*`、`tsx=off`、`mmio_stale_data=*`、`retbleed=*`、`gather_data_sampling=force`、`reg_file_data_sampling=on`、`indirect_target_selection=force`、`vmscape=force`）整组不采纳 | 大多 Intel/KVM-only（`libvirtd` 关着）；信任 `mitigations=auto` 而非逐个 CVE 手焗 |
| `nosmt`、`kpti=1`/`pti=on`、`slab_debug=FZ`（Kicksecure） | 2026-08-11 已否 |
| `intel_iommu=on` 不采纳 | omen15 是 AMD |
| `ia32_emulation=0` 不采纳 | 会打断 32 位 Steam/Proton |
| PCIe ACS override 补丁——不追 | 无 vendor 来源；等 VFIO 撞上分组问题再处理 |
| `lockdown=confidentiality`→`integrity`，仍无效 | 见 `known-breaking-settings.md` |
| `ima_policy=tcb`——不采纳 | 真实可用（只度量，`CONFIG_IMA_APPRAISE` 未编），留待以后 |
| `cfi=kcfi`、`extra_latent_entropy`——无效，保留 | 见 `known-breaking-settings.md` |
| `proc_mem.force_override=ptrace`——刻意降级编译默认值 | 见 `known-breaking-settings.md` |

### 2026-08-12（续：溯源表里剩下的"未复查"行——ananicy/zram/scx/kloak/MAC 随机化/srvos，`diff_sysctl.py` 都碰不到）

| 项目 | 取舍理由 |
|---|---|
| 性能 sysctl（`vm.*` 块）/ BBR+CAKE+TCP 调参——无新缺口 | `diff_sysctl.py` 重新确认过:只有 4 个 `DIFFERS`,全部已经在 2026-08-11 的记录里决定过了（`vm.dirty_background_bytes`、`vm.max_map_count`、`vm.mmap_rnd_bits` 架构条件误报、`vm.swappiness`） |
| ananicy 规则集——不需要静态 diff | `pkgs.ananicy-rules-cachyos` 是活的 nixpkgs 依赖,不是 vendor 快照——结构上就自动跟着上游走 |
| zram-generator 大小/算法——无新缺口 | 已经决定过的 16GB 封顶（2026-08-11）对比 cachyos 不封顶的 `ram`；`compression-algorithm=zstd` 一致 |
| cachyos `30-zram.rules` 里内联的 `SYSCTL{vm.swappiness}="150"` 不移植 | 是在 zram 设备初始化那一刻的冗余再确认（对比本仓库开机时就生效的 `mkOverride 950` sysctl）；而且数值本来就不一样（150 对我们刻意选的 180）,搬过来反而跟现有 sysctl 打架——低风险,不追 |
| scx 调度器——无法 diff | `linux-cachyos`/sched-ext 不在已 vendor 的 `cachyos` 快照里（那是 `CachyOS-Settings`,不同仓库）；没有本地 vendor 内容可以拿来对比 `scx_rusty` |
| snd-hda-intel udev——确认是刻意简化,不是缺口 | 本仓库在电池上直接写死 `power_save=1`、AC 上写死 `0`；cachyos 的 `20-audio-pm.rules` 则是在第一次启动时捕获驱动实际出厂默认值,电池模式下还原成*那个*值。更简单且看起来是刻意的；真正日常要紧的 AC（防爆音）行为两边完全一致 |
| PCIe ASPM/`amd_pstate=active`/teo governor（`powersave.nix`）——确认自研,无法 diff | vendor 过来的 `cachyos` 快照里没有任何文件提到 `amd_pstate`、`pcie_aspm` 或 `cpuidle`；溯源表"自研 udev 脚本"的标注准确,没有东西可对比 |
| kloak——现有工具无法复查 | kloak 自己的上游仓库从没被 vendor 过（只用了 nixpkgs 的二进制包）；8 个 `refresh.sh` 来源里没有 kloak 本身。真要 diff 得加第 9 个 vendor 来源 |
| IPv6 隐私地址 / MAC 随机化——无缺口 | `wifi.macAddress`/`wifi.scanRandMacAddress`/`ethernet.macAddress`（仅桌面）早就在 `privacy.nix:157-160` 全面设好了；一开始标"未复查"是记录没跟上,不是真缺口 |
| srvos——没有活的来源可以 diff | 不是 flake input（`flake.nix`/`flake.lock` 确认没有 `srvos` 条目）；`boot.tmp.cleanOnBoot` 等是一次性手动改编的参考,不是持续依赖 |

### 2026-08-12（续：完整性核查引发的，对全部 9 个来源做的新一轮 `*.d` 目录全量重新扫描）

| 项目 | 取舍理由 |
|---|---|
| `networking.firewall.extraCommands`：`ip46tables -P INPUT DROP`(新增） | NixOS 自己的 iptables `firewall.service` 从没设过 INPUT 链基础策略——所有过滤逻辑都靠一条跳转到 `nixos-fw` 链的规则,关机时 `stopScript` 会把这条规则删掉（`conflicts=shutdown.target`），在机器真正断电前留出一段 INPUT 默认 ACCEPT 策略暴露的窗口。跟 Tails `ferm.service.d` 修的问题（tails#20536）是同一类故障。失效兜底,已在构建出的脚本里验证过会在跳转规则加上之前先执行,不影响正常运行 |
| `dbus-broker.service.d`(pop-default-settings：`Restart=on-failure`、`LimitNOFILE` 提高)不采纳 | 本轮不追 |
| Tails 剩下约 40 个新枚举出来的 `*.d` 分类（GNOME 服务、Tor/onion-grater、live-boot 钩子、dconf、应用专属 D-Bus 策略） | 确认不适用——跑 niri 不是 GNOME，没用 Tor，永久安装不是 live-boot |

### 2026-08-13（隔天检查：对全部 9 个来源跑 `git ls-remote`，只对动过的跑 diff）

| 项目 | 取舍理由 |
|---|---|
| secureblue/bazzite/grapheneos-infra 有更新，另外 6 个不变 | GitHub compare 直接 diff，不整体重新 vendor：bazzite 只改了 README，grapheneos-infra 只是 `rbl.conf` 域名换位置（无新增），secureblue 除 CI/脚本外见下两条。`diff_sysctl.py`/`diff_misc.py` 重跑：输出跟 2026-08-11/12 完全一致 |
| 从 `core.nix` 的 `extraFlags` 里删掉 chrony `-F 1`（SCFILTER） | 所有主机上 `chronyd` 崩溃循环（SIGSYS）——其内建 seccomp 白名单假设 glibc + glibc malloc，`pkgsMusl.chrony` 链的是 musl + `libhardened_malloc-light.so`。保留 `-r` |
| `preservation.nix`：给 `/var/lib/chrony` 显式写上 `user`/`group`/`mode` | 原本继承模块 `0755 root:root` 默认值，悄悄覆盖了 NixOS chrony 模块自己的 `0750 chrony:chrony`，导致建不了新文件。列表里其它条目也查过同类问题，chrony 是唯一真正中招的 |
| secureblue 新增的 `bash-timeout.sh`（服务器 `TMOUT=300`，空闲自动登出）不采纳 | `server.nix` 的真实候选项，目前本仓库哪都没设 `TMOUT` |
| 无关发现：`nix flake check` 在 `packages.x86_64-linux.iso-installer` 上失败（`plasma6` vs `niri` 冲突） | 既有问题，跟这次复查无关，没有在这里修 |

## 季度复查流程（方案 A：手动）

每季度最后一个周末执行一次（建议在日历上设提醒）：

1. **拉取上游**——跑 `docs/upstream-vendor/refresh.sh`（自动覆盖
   CachyOS/Kicksecure/secureblue/Bazzite/nix-mineral/Pop!_OS/GrapheneOS-infra/OpenBSD/Tails）；
   只手动浅克隆这个集合之外还剩的：`Kicksecure/hardened-kernel`（Kconfig，不追，见溯源表）
2. **diff**：自动化来源用 `docs/upstream-vendor/diff_sysctl.py` 和
   `diff_misc.py`；没有解析器的内容（udev 规则、AppArmor、systemd
   `.service.d`/`.slice.d`——见 `docs/upstream-vendor/README.md` 的覆盖面表）
   人工对照上次复查记录
3. **更新本表**：把「最近复查」日期和上游版本/commit 填上；新出现的设置按
   状态图例标记
4. **候选变更逐项实验**：从风险最低的主机开始滚 **oci → rpi → omen15**，
   每项先 `nixos-rebuild build` 再上机验证；每一项的结论（保留/否掉）写进
   `known-breaking-settings_zh.md`
5. **合并**：只合经过实验的设置；README「Reference Sources」如有新来源一并更新
