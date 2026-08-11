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
| hardened malloc（graphene-hardened-light） | 部分游戏/性能敏感应用掉帧 | 硬化分配器有开销 | 保留；注释留档 scudo（均衡）/mimalloc（性能）备选 | hardened.nix | 游戏帧率对比 |
| `cfi=kcfi` | 整体性能损耗 | 内核 CFI 是复杂度换安全 | 保留（已注明 slightly performance loss） | KSPP | 无 |
| `slub_debug=FZP` | 10-20% 性能开销 | 分配调试（完整性+红区+填毒） | 停用，仅开发排查期临时开 | 实测（注释留档） | 无 |
| earlyoom 误杀 | 游戏/Wine 进程被 OOM 杀掉 | earlyoom 阈值太激进 | 保留——`--avoid (exe|steam|wine|gamescope|mangohud|proton)` | 实测 | 大内存负载下开游戏 |
| kloak 常驻 | niri 全局快捷键、fcitx5 输入法失效 | kloak 独占抓取真实键盘（设计如此） | 保留——不设 wantedBy，手动 `doas systemctl start/stop kloak` | Whonix | 手动启停验证 |
| `vm.swappiness` 高值（180/150） | 无 zram 的机器会过度使用磁盘 swap | 高 swappiness 是为 zram 压缩内存设计的 | 保留——与 `zram-generator` 绑定，禁 zram 必须同时改回 | CachyOS | 看 `zramctl` 是否在跑 |
| zswap 与 zram 共存 | 内存压力表现怪异 | 两个压缩交换栈打架 | 已处理——`zswap.enabled=0` + zram0 初始化后禁 zswap | CachyOS | `zramctl`/`/sys/module/zswap/parameters/enabled` |

## C. 上游模块与内核版本打架

| 现象 | 根因 | 处置 |
|---|---|---|
| 模块 meta.broken：跟不上锁定内核版本 | 上游模块（如 LKRG、tirdad）对新内核 API 支持滞后 | 升级内核前先查对应上游是否支持（见 `hosts/isolive/isolive.nix` 注释）；CI 会挡掉 build 失败 |

## 实验纪律（怎么避免"机器起不来"）

1. 默认滚动顺序：**oci → rpi → omen15**（服务器炸了损失最小，主力笔记本最后上）
2. 直连机器上：NixOS 有 generation 回滚兜底（`nixos-rebuild list-generations` + 开机引导菜单选旧 generation），但**只有换掉崩溃参数的那一代才能救回来**——所以一次只改一个设置组
3. 远程机器（oci/rpi）：先 `nixos-rebuild build`（不 activate），确认 build 通过再 switch；换内核参数这类启动期设置时，准备好 rescue 手段（Oracle Cloud 的 VNC/console、rpi 的串口）
4. 新设置上机前先在 `nix flake check` + CI 构建矩阵过一遍（它们不启动系统，但能挡掉拼写/类型错误）