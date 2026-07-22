# hydroakri 的 NixOS 与 Dotfiles

[![CI](https://github.com/hydroakri/dotfiles/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/ci.yml)
[![Update Flake Lock](https://github.com/hydroakri/dotfiles/actions/workflows/update-flake-lock.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/update-flake-lock.yml)

> 面向 Wayland 桌面与 ARM 服务器的多主机 NixOS flake + Chezmoi dotfiles。

*[English](README.md)*

本仓库打包了两个相互独立、松耦合的部分：一个多主机 NixOS flake
（`flake/` —— 声明式机器配置）和一套由 chezmoi 管理的 dotfiles
（其余部分 —— Wayland 桌面会话配置）。它们共享一个目录，但不共享代码：
`flake/` 与 `utils/` 通过 `.chezmoiignore` 被排除在 chezmoi 部署之外，
而 dotfiles 本身并不局限于 NixOS。跳转到
[NixOS Flake](#nixos-flake) 或 [Dotfiles (Chezmoi)](#dotfiles-chezmoi)。

## ⚠️ 警告

**这是我的个人配置，请勿盲目直接使用。**

其中的密钥、机密信息、硬件 ID 和域名均为我本人所有。这些模块被设计为
可复用的 —— 参见 [作为 Flake Input 使用](#作为-flake-input-使用) —— 但你必须
为 `modules.security` 下的所有内容以及 `mainUser` 提供你自己的值。

## 仓库结构

```
flake/          NixOS flake（多主机，声明式）
├── hosts/      各机器的入口配置
├── modules/    主机共享导入的模块
│   ├── core.nix          所有主机的基础层
│   ├── desktop.nix       桌面配置（低延迟调优）
│   ├── server.nix        服务器配置（吞吐量调优）
│   └── features/         可选启用的功能
└── templates/  开发环境模板（ros2）

dot_config/     由 chezmoi 管理的 dotfiles → ~/.config/
dot_local/      由 chezmoi 管理 → ~/.local/（Flatpak 应用覆盖，KDE Flexoki 配色方案）
dot_var/        由 chezmoi 管理 → ~/.var/（VSCodium Flatpak 配置）
dot_zshrc       → ~/.zshrc
utils/          脚本（不由 chezmoi 部署）。部分被 WM 配置引用的脚本
                尚未提交到仓库 —— 参见 Gotcha 1。
```

`flake/` 与 `utils/` 通过 `.chezmoiignore` 被排除在 chezmoi 部署之外。

---

## NixOS Flake

### 主机列表

| 主机 | 架构 | 配置 | 角色 |
|------|------|---------|------|
| `omen15` | x86\_64 | desktop | 主力笔记本（AMD + NVIDIA） |
| `oci` | aarch64 | server | Oracle Cloud —— 自托管服务 |
| `rpi4-side-gateway` | aarch64 | server | 树莓派 4 —— 透明代理网关 |
| `rpi4-switch` | aarch64 | server | 树莓派 4 —— 路由器 / SQM 交换机 |

> `oci` 还运行了一个仅限本机的 `features/agent.nix`（"hermes-agent"，一个
> 基于 Telegram 机器人的 AI 代理），该模块未通过 `nixosModules` 导出，
> 因此不在下方的模块表中 —— 它只会被 `oci` 直接导入。

### 作为 Flake Input 使用

将本 flake 添加为 input，然后导入你需要的任意 `nixosModules.*`：

> **注意：** `nixosModules.core` 内部使用了 `inputs`（nix-index-database）。
> 你必须在 `lib.nixosSystem` 调用中传入 `specialArgs = { inherit inputs; }`。

```nix
# flake.nix
inputs.hydroakri-nixos.url = "github:hydroakri/dotfiles?dir=flake";

# 你的主机配置（lib.nixosSystem）
# specialArgs = { inherit inputs; };   ← 使用 nixosModules.core 时必须设置
{ inputs, ... }: {
  imports = [
    inputs.hydroakri-nixos.nixosModules.core
    inputs.hydroakri-nixos.nixosModules.security
    inputs.hydroakri-nixos.nixosModules.performance
  ];

  mainUser = "alice";                           # 默认值 "user" 无实际作用 —— 务必自行设置

  modules.core.extraSubstituters = [            # 可选的额外缓存
    "https://nix-community.cachix.org"
  ];
  modules.core.extraTrustedPublicKeys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  modules.security.authorizedKeys = [           # 允许 root 登录的 SSH 公钥
    "ssh-ed25519 AAAA... alice@laptop"
  ];
  modules.security.u2fMappings = ''             # 留空则跳过 u2f PAM
    alice:<pamu2fcfg output>
  '';
}
```

上面只展示了 `core`、`security` 和 `performance`，因为它们的
`nixosModules` 名称与 `modules.*` 配置命名空间是一一对应的。对于其他
所有模块，导入名与配置路径并不相同 —— 在设置选项之前，请先查看下方表格中的
**配置路径**列。

### 可用的 `nixosModules`

| 名称 | 说明 | 配置路径 |
|------|-------------|--------------|
| [`core`](flake/modules/core.nix) | 所有主机的基础层：Nix 设置与额外的二进制缓存、Unbound DNS、Chrony NTS、终端工具、SMART 监控。同时也导入了 `sqm.nix`/`tuning.nix`，因此每台主机都自带 SQM 与网卡调优能力（默认均为禁用）。需要注意的副作用：将 `networking.nameservers` 硬编码为 Cloudflare（`172.64.36.2`）+ Quad9（`149.112.112.11`），并且一条 SSH 客户端覆盖规则会将所有 `github.com` 流量路由经过 `ssh.github.com:443`。 | 始终启用；`modules.core.extraSubstituters` / `extraTrustedPublicKeys` |
| [`desktop`](flake/modules/desktop.nix) | 桌面配置：`preempt=full`、PipeWire、XDG portals、Vulkan/OpenGL。按惯例不与 `server` 同时使用 —— 没有 `assertions` 强制约束，仅靠主机文件的自律约定。 | 始终启用 |
| [`server`](flake/modules/server.nix) | 服务器配置：`preempt=voluntary`、tuned、fail2ban、irqbalance。按惯例不与 `desktop` 同时使用（同上）。 | 始终启用 |
| [`performance`](flake/modules/features/performance.nix) | BBR+CAKE 网络、MGLRU、zram、scx 调度器、I/O 调度器 udev 规则。 | 始终启用；`modules.performance.vendor` |
| [`security`](flake/modules/features/security.nix) | 内核加固、AppArmor、doas、u2f PAM、FIDO2 SSH、USBGuard、sysctl 基线配置。 | 始终启用；`modules.security.authorizedKeys` / `u2fMappings` |
| [`privacy`](flake/modules/features/privacy.nix) | 反追踪/反指纹识别：Brave 加固策略、kloak 键盘鼠标时序匿名化、MAC 地址随机化、IPv6 隐私地址。 | 始终启用 |
| [`powersave`](flake/modules/features/powersave.nix) | `power-profiles-daemon`、s2idle、动态音频省电 udev 规则。 | 受控：`modules.powersave.enable` |
| [`gaming`](flake/modules/features/gaming.nix) | scx_lavd 调度器、Gamescope、GameMode、Steam 防火墙端口。导入本模块**不会**自动开启 Steam —— `programs.steam.enable` 默认仍为 `false`。 | 始终启用（Steam 需单独开启） |
| [`utils`](flake/modules/features/utils.nix) | Prometheus + node-exporter、Grafana、Uptime Kuma，以及 `enableGraphicTools`（GPU 诊断工具包）。*Glance 并未在此配置* —— 它仅作为 `oci` 上一个指向未在 Nix 中声明的服务的裸 nginx 反向代理 vhost 存在（需带外运行）。 | 受控：`modules.utils.enable` |
| [`virtualisation`](flake/modules/features/virtualisation.nix) | Podman + Docker shim、用于 aarch64 交叉运行的 qemu binfmt。 | 始终启用 |
| [`preservation`](flake/modules/features/preservation.nix) | 基于 tmpfs 根目录的 preservation 状态持久化（NetworkManager 状态、Unbound/Chrony 状态、SSH host key、machine-id、多个服务的 `/var/lib/*`）；由 `omen15` 使用。 | 受控：`modules.preservation.enable` / `persistentPath` |
| [`networking-proxy`](flake/modules/features/networking/proxy.nix) | sing-box FakeIP + dnscrypt-proxy + AdGuardHome + 可选的 dae eBPF。 | 受控：`modules.proxy.enable` |
| [`networking-router`](flake/modules/features/networking/router.nix) | NAT 路由器：VLAN、DHCP、MSS 钳制，并禁用严格反向路径过滤（`networking.firewall.checkReversePath = false`）。 | 受控：`modules.router.enable` |
| [`networking-sqm`](flake/modules/features/networking/sqm.nix) | 通过 `tc` 实现的 CAKE SQM —— WAN 接口上的缓冲膨胀（bufferbloat）控制。已被 `core` 引入（默认禁用）；大多数主机不需要直接导入此模块。 | 受控：`modules.networking.sqm.enable` |
| [`networking-tuning`](flake/modules/features/networking/tuning.nix) | sysfs 网卡调优：通过 udev 实现 RPS/XPS CPU 亲和性。已被 `core` 引入。 | 受控：`modules.networking.sysfsTuning.enable` |
| [`hardware-amd`](flake/modules/hardware/amd.nix) | AMD GPU：始终启用 `hardware.amdgpu.overdrive` + `services.lact`（GPU 控制守护进程）；ROCm 为可选启用。**不**配置 zenpower —— 那是按主机手动构建的，仅在 `omen15` 上（自定义内核模块构建）。 | 基础部分始终启用；ROCm 受 `modules.amd.rocm` 控制 |
| [`hardware-nvidia`](flake/modules/hardware/nvidia.nix) | NVIDIA 驱动（通过 `variant` 选择 open/proprietary/nouveau）、prime offload。 | 受控：`modules.nvidia.enable` |
| [`filesystem-btrfs`](flake/modules/filesystems/btrfs.nix) | Btrfs 维护：`services.btrfs.autoScrub`、自定义的 `btrfs-balance` oneshot+timer、`services.snapper`（对 `/` 与 `/home` 每小时快照）。**不**设置子卷布局/压缩/挂载选项 —— 这些是主机特定的，参见 `flake/hosts/omen15/disko.nix`（目前唯一的使用者）。 | 始终启用 |

**受控模块一览：** `powersave`、`utils`、`preservation`、
`networking-proxy`、`networking-router`、`networking-sqm`、
`networking-tuning`、`hardware-nvidia`，以及 `hardware-amd` 的 `rocm`
子选项。其余模块只要被导入即为始终启用。

### 关键选项

**`mainUser`** *(字符串，默认值：`"user"`)* —— 系统用户名；在各模块中用于 home 路径、用户组和 PAM。

**`modules.core.extraSubstituters`** *(列表)* —— 附加在 `cache.nixos.org` 之后的二进制缓存。

**`modules.core.extraTrustedPublicKeys`** *(列表)* —— 额外缓存对应的受信任公钥。

**`modules.security.authorizedKeys`** *(列表，默认值：`[]`)* —— 允许 root 登录的 SSH 公钥。默认为空表示禁用 root SSH 登录；在任何需要远程访问的主机上都必须设置此项。

**`modules.security.u2fMappings`** *(多行字符串)* —— `/etc/u2f_mappings` 的内容，来自 `pamu2fcfg -n`；空字符串表示完全禁用 u2f PAM。

**`modules.performance.vendor`** *(枚举：`amd` | `intel` | `other`，默认值：`"other"`)* —— 选择微码更新包。默认值 `"other"` 会完全跳过微码更新；在已知 CPU 厂商的情况下应始终显式设置为 `amd` 或 `intel`，因为没有自动检测机制。

### 常用命令

（以下命令用于构建/管理本仓库自身的主机。如果你是将本 flake 作为其他仓库的
依赖来使用，请参见上方的"作为 Flake Input 使用"。）

```bash
# 构建并切换（在仓库根目录执行）
nh os switch -H omen15 ./flake
nh os switch -H oci ./flake
nh os switch -H rpi4-side-gateway ./flake

# 仅测试构建，不激活
nixos-rebuild build --flake ./flake#omen15

# 更新 flake 输入
nix flake update --flake ./flake

# 构建镜像
nix build ./flake#packages.x86_64-linux.iso-installer
nix build ./flake#packages.aarch64-linux.rpi-image

# 在其他地方初始化 ROS2 开发环境
nix flake init -t 'github:hydroakri/dotfiles?dir=flake#ros2'
```

### CI / 构建流水线

本 flake 由两个 GitHub Actions 工作流负责构建与维护：

- **`ci.yml`**（"CI"）—— 在推送/PR 到 `main`（按 `flake/**` 路径过滤）、
  每日定时任务或手动触发时：运行 `nix flake check`（模块断言检查加上
  nixfmt/statix/deadnix 格式检查），然后对全部四个
  `nixosConfigurations.*.config.system.build.toplevel` 进行矩阵构建
  （`omen15` 在 x86_64-linux/ubuntu-24.04 上；`oci`、`rpi4-side-gateway`、
  `rpi4-switch` 在 aarch64-linux/ubuntu-24.04-arm 上），并推送到自托管的
  Attic 缓存 `cache.hydroakri.cc`，以及一个名为 "LanTian" 的辅助
  substituter。该矩阵并非手写 —— 而是通过 `nix-github-actions` input
  在 CI 运行时通过 `nix eval .#githubActions.matrix` 生成。x86_64 任务
  会先执行一步磁盘清理。
- **`update-flake-lock.yml`** —— 每日定时（也支持手动触发），检查
  NixOS Hydra 频道健康状况与内核哈希漂移情况，在条件满足时通过
  `DeterminateSystems/update-flake-lock` 打开一个自动合并的 PR 来更新
  `flake.lock`。该 PR 会修改 `flake/flake.lock`，进而触发 `ci.yml` 作为
  合并前的实际把关检查。

> 如果你将本 flake 作为 input 使用，请将 `cache.hydroakri.cc` 添加到
> `modules.core.extraSubstituters` —— CI 会持续为其填充预构建的主机产物。

### 密钥管理（sops-nix）

```bash
# 编辑加密密钥（在 flake/modules/features/secrets/ 目录下执行）
sops secrets.yaml

# 修改 .sops.yaml 中的 recipients 后重新加密
sops updatekeys secrets.yaml
```

密钥使用 age 加密。Recipients 定义在 `.sops.yaml` 中，并与各主机的
SSH ed25519 host key 绑定。**在重装系统前务必备份 `/etc/ssh`** ——
丢失 host key 会导致密钥永久无法解密。

---

## Dotfiles (Chezmoi)

通过 chezmoi 的命名约定进行管理：`dot_config/` → `~/.config/`，
`executable_` → `+x`。

```bash
chezmoi diff          # 预览变更
chezmoi apply         # 部署到 $HOME
chezmoi apply ~/.config/niri  # 仅应用单个目标
chezmoi update        # 拉取并应用
```

### 桌面技术栈

- **合成器（Compositor）**：Hyprland、Niri、Sway（Wayland）
- **终端 / Shell**：通过 **antidote**（插件管理器 —— 首次运行时会执行
  一次阻塞式的 `git clone --depth=1`，随后 `antidote load` 读取
  `dot_zsh_plugins.txt`：zsh-completions、fzf-tab、zsh-sage）管理的 Zsh，
  以及 **zsh-patina**（语法高亮，通过 `curl`+`tar` 从 GitHub release
  压缩包单独获取）；WezTerm、Ghostty
- **主题**：Flexoki + Adw-gtk3 + qt6ct，通过 `utils/chtheme.sh` 集中管理。
  脚本中存在 Pywal 支持以及 zellij/wezterm/alacritty 配色注入代码，
  但目前处于注释/未启用状态。仅支持 qt6ct —— `dot_config/qt5ct/colors/`
  下存在 qt5ct 配色文件，但 chtheme.sh 并未处理它们。
- **输入法**：Fcitx5 + rime-wanxiang，由 `desktop` flake 模块以 Nix 包的
  形式提供（`pkgs.fcitx5-rime`、`pkgs.rime-wanxiang`、`pkgs.fcitx5-gtk` 等）
  —— 并非通过 chezmoi
- **外部插件管理器**：`.chezmoiexternal.toml` 中唯一的条目用于拉取
  tmux 的 TPM 到 `~/.tmux/plugins/tpm`；zsh 插件通过上述 antidote 管理

### 注意事项（Gotchas）

1. **`~/utils/` 不由 chezmoi 部署** —— WM 配置中硬编码了 `~/utils/`
   路径（Hyprland 会执行 `~/utils/bemenu`、`~/utils/rofi.sh`、
   `~/utils/gamemode.sh`、`~/utils/chgwllpr.sh`）。**已知缺口：** 这四个
   脚本目前均未提交到 `utils/` —— 该目录目前只包含 `chtheme.sh`、
   `screen-locker.sh`，以及一个存放静态扩展设置快照的 `backup/` 文件夹。
   在这些键位绑定/exec 生效之前，你需要自行编写这些脚本。

2. **`utils/chtheme.sh` 会就地修改配置** —— 重写
   `~/.config/qt6ct/qt6ct.conf`（qt5ct 不受影响）、GTK CSS 以及 mako
   配置，然后重新加载 mako/gsettings/plasma 的配色方案。脚本中存在
   Pywal 调用与终端配色注入代码，但均处于注释状态。如果你不使用
   Flexoki + Adw-gtk3 + qt6ct，请禁用或修改此脚本。

3. **壁纸路径为硬编码** —— 各合成器期望壁纸位于
   `~/Pictures/wllppr/wall.jpg`。请填充该路径或自行修改。

4. **Zsh 插件引导过程是同步的，而非后台执行** —— `.zshrc` 使用
   antidote 作为插件管理器；首次运行时会执行一次阻塞式的
   `git clone --depth=1` 来安装 antidote，随后加载
   `dot_zsh_plugins.txt`（zsh-completions、fzf-tab、zsh-sage）。此外，
   `.zshrc` 还会通过 `curl`+`tar` 从 GitHub release 同步获取
   `zsh-patina` 并放入 `~/.zsh/zsh-patina`。在全新机器上或清空
   `~/.zsh/` 后，预期会有启动延迟。

---

## 许可证

[MIT](LICENSE) —— 欢迎 fork 和二次开发。
