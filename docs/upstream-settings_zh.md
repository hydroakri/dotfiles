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
| 基础 sysctl 基线（kernel.* 指针/dmesg/bpf、net.* ARP/ICMP/重定向、fs.protected_* 等） | Kicksecure `security-misc` 的 `/usr/lib/sysctl.d/990-security-misc.conf`（KSPP 推荐基线）+ ANSSI 指南（注释中 R8/R9/R12/R33） | `security.nix` 950 优先级块 | 已移植（改：合并了 ANSSI 项、`ptrace_scope` 降到 1、`io_uring_disabled` 桌面留 1） | 未复查 |
| 内核启动参数（slab_nomerge、lockdown、cfi、init_on_alloc、oops=panic…） | KSPP / nixpkgs `hardened.nix` / madaidans-insecurities（nix-mineral 同源思路） | `security.nix` `boot.kernelParams` | 已移植 | 未复查 |
| 服务器严格模式块（io_uring/perf/binfmt_misc 全禁） | Kicksecure `security-misc`（server 变体）+ 自研按有无显示服务器区分 | `security.nix` 900 优先级块 | 已移植 | 未复查 |
| I/O 调度器 udev 规则（kyber/mq-deadline/bfq）、hdparm -B 254 -S 0、cpu_dma_latency 属组 audio | CachyOS `CachyOS-Settings` `usr/lib/udev/rules.d/60-ioschedulers.rules` | `performance.nix` `services.udev.extraRules` | 已移植（规则原文改编） | 未复查 |
| 性能 sysctl（dirty_bytes、vfs_cache_pressure、page-cluster、watermark、min_free_kbytes…） | CachyOS `CachyOS-Settings` `usr/lib/sysctl.d/70-cachyos-settings.conf` | `performance.nix` `boot.kernel.sysctl`（vm.* 块） | 已移植（swappiness 改为 180、补 watermark/compaction 等） | 未复查 |
| BBR + CAKE qdisc、TCP 缓冲调参 | CachyOS / 通用网络调优（Fq_codel 系） | `performance.nix` net.* 块 | 已移植 | 未复查 |
| ananicy 进程优先级 + cachyos 规则集 | CachyOS（ananicy-cpp + ananicy-rules-cachyos） | `performance.nix` `services.ananicy` | 已移植 | 未复查 |
| zram-generator（ram/2, zstd）+ zswap 禁用 | CachyOS 默认（systemd-zram-generator + CachyOS-Settings 联动） | `performance.nix` | 已移植 | 未复查 |
| scx 调度器（scx_rusty） | CachyOS `linux-cachyos`（sched-ext 系） | `performance.nix` `services.scx` | 已移植 | 未复查 |
| snd-hda-intel AC/电池电源管理 udev | CachyOS `CachyOS-Settings` udev 规则 | `powersave.nix` | 已移植 | 未复查 |
| PCIe ASPM 策略、amd_pstate=active、teo governor | CachyOS / TLP 思路（自研 udev 脚本） | `powersave.nix` | 已移植 | 未复查 |
| kloak（击键/鼠标时序匿名化） | Whonix / kloak 上游（nixpkgs 只有二进制） | `privacy.nix` | 部分移植（自写 systemd 单元 + Wayland 探测） | 未复查 |
| IPv6 隐私地址、MAC 随机化 | 通用基线（Kicksecure 网络硬化亦有） | `privacy.nix` | 已移植 | 未复查 |
| 内核模块黑名单 | Kicksecure `security-misc`（蓝牙等）→ nix-mineral 亦有 | 未移植（当前只禁了必要项） | 仅参考 | — |
| sysctl 全套逐项对照 | nix-mineral、secureblue、Bazzite | `docs/upstream-vendor/diff_sysctl.py`——自动逐项对比本仓库声明的 sysctl,不代表对任何一项做了取舍决定 | 仅参考(工具) | 2026-08-11 |
| 内核 Kconfig 硬化 | Pop!_OS `linux`、Qubes `qubes-linux-kernel`、Kicksecure `hardened-kernel`、KSPP 推荐项一般性参考 | — | 不追踪(2026-08-11 移除:本仓库自己编译 CachyOS 内核,任何 Kconfig 发现都要靠维护内核补丁/`structuredExtraConfig` 才能落地,不是改一行 Nix 那么简单,维护成本不划算) | — |
| AppArmor profile 集 | Tails `config/`(AppArmor 硬化) | `security.nix` 只启用了 nixpkgs 自带 profiles | 仅参考 | — |
| 内核 config 级硬化 | Pop!_OS `linux` / Qubes `qubes-linux-kernel` / Kicksecure `hardened-kernel` | 未移植(NixOS 内核 config 改造是独立项目;已自动化的部分见上面 Kconfig 检查) | 仅参考 | — |
| secureblue 全套(dconf/sysctl/udev) | `secureblue/secureblue` | sysctl:已自动 diff(见上)。dconf/udev:未移植 | 仅参考 | — |
| Bazzite 桌面/游戏向 sysctl + udev | `ublue-os/bazzite` `system_files/desktop/shared` | sysctl:已自动 diff(见上)。udev:已 vendor,手动 `diff -ru` | 仅参考 | — |
| srvos(boot.tmp.cleanOnBoot 等) | nix-community/srvos | `security.nix` 个别行 | 部分移植 | 未复查 |

## 复查记录

一行一个决定。已 vendor 的来源:CachyOS、Kicksecure、secureblue、Bazzite、
nix-mineral、Pop!_OS `default-settings`、GrapheneOS `infrastructure`(共 7
个)。过程/工具类记录(修的 bug、查过但没结果的来源、覆盖面方法论)放在
`docs/upstream-vendor/README.md`,这里不重复。

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

## 季度复查流程（方案 A：手动）

每季度最后一个周末执行一次（建议在日历上设提醒）：

1. **拉取上游**（浅克隆到 `/tmp/upstream-review/`）：
   `Kicksecure/security-misc`、`Kicksecure/hardened-kernel`、
   `secureblue/secureblue`、`CachyOS/CachyOS-Settings`、
   `tails/tails`（gitlab.tails.boum.org）、`cynicsketch/nix-mineral`
2. **diff 关键文件**：`990-security-misc.conf`、`70-cachyos-settings.conf`、
   nix-mineral 的 `settings/`、Tails 的 `config/`，与上次复查记录对比
3. **更新本表**：把「最近复查」日期和上游版本/commit 填上；新出现的设置按
   状态图例标记
4. **候选变更逐项实验**：从风险最低的主机开始滚 **oci → rpi → omen15**，
   每项先 `nixos-rebuild build` 再上机验证；每一项的结论（保留/否掉）写进
   `known-breaking-settings_zh.md`
5. **合并**：只合经过实验的设置；README「Reference Sources」如有新来源一并更新
