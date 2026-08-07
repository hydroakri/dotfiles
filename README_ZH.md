# hydroakri 的 NixOS 与 Dotfiles

[![CI](https://github.com/hydroakri/dotfiles/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/ci.yml)
[![Update Flake Lock](https://github.com/hydroakri/dotfiles/actions/workflows/update-flake-lock.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/update-flake-lock.yml)
[![Update Home Manager Lock](https://github.com/hydroakri/dotfiles/actions/workflows/update-home-manager-lock.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/update-home-manager-lock.yml)

> 多主机 NixOS flake + 一个可移植的 home-manager flake + chezmoi dotfiles。

*[English](README.md)*

## 目录

- [⚠️ 这是我的个人配置](#personal-config)
- [你可能需要知道的默认值](#你可能需要知道的默认值)
- [我该怎么...](#我该怎么)
  - [...在自己的 flake 里复用单个模块?](#在自己的-flake-里复用单个模块)
  - [...新增或切换一台主机?](#新增或切换一台主机)
  - [...编辑或轮换 secrets?](#编辑或轮换-secrets)
  - [...开启一个默认关闭的模块?](#开启一个默认关闭的模块)
  - [...用 home-manager 引导 CLI 工具集?](#用-home-manager-引导-cli-工具集)
  - [...应用或更新我的 dotfiles?](#应用或更新我的-dotfiles)
  - [...解决已知的 dotfiles 坑?](#解决已知的-dotfiles-坑)
- [Reference](#reference)
  - [仓库结构](#仓库结构)
  - [主机](#主机)
  - [可用的 `nixosModules`](#可用的-nixosmodules)
  - [关键选项](#关键选项)
  - [常用命令](#常用命令)
  - [CI / 构建流水线](#ci-build-pipeline)
  - [Home Manager](#home-manager)
  - [桌面技术栈](#桌面技术栈)
- [License](#license)

<a id="personal-config"></a>

## ⚠️ 这是我的个人配置——复用前请先读这段

主机名、`hydroakri.cc` 域名、真实的 SSH/FIDO2 公钥、sops 加密的 secrets,都放在
`flake/hosts/*`、`flake/hosts/personal-proxy-profile.nix`、
`flake/modules/features/secrets/` 里。**这些文件都没有导出为
`nixosModules`**,所以 [Reference](#reference) 里任何一个模块的导入都不会带出
我的 secrets——模块本身是扩展点,不是身份信息。

需要你自己填的:`mainUser`、`modules.security.authorizedKeys`、
`modules.security.u2fMappings`,如果想用自己的二进制缓存还有
`modules.core.extraSubstituters`。它们默认是空值/不可用的值,就是故意的。

有几个模块里还硬编码了一些"基础设施默认值"——不算 secret,但也是我的个人选择,
不是通用默认值。比如 `core.nix` 的 DNS 解析器(Cloudflare + Quad9)和它给
`Host github.com` 加的走 443 端口的 SSH 路由。用之前先看代码,别假设默认值适合你。
完整清单见 [你可能需要知道的默认值](#你可能需要知道的默认值)。

---

## 你可能需要知道的默认值

下面这些都不是 secret——是藏在共用模块里的基础设施/软件包选择,复用的人
(或者未来的我)很容易漏看:

| 默认值 | 在哪 | 为什么可能出乎意料 |
|---|---|---|
| **用的是 Lix,不是上游 Nix** | `core.nix`:`nix.package = pkgs.lix;`(独立的 home-manager flake 里也单独设了一遍) | 这个仓库管的每台主机上跑的 daemon 都是 Lix fork,不是 `nixpkgs` 自带的 Nix。 |
| **用 Rust coreutils,不是 GNU** | `core.nix`:`lib.hiPrio pkgs.uutils-coreutils-noprefix` | `uutils` 在 `PATH` 里把 GNU coreutils 遮住了。大部分兼容,但不是逐字节对齐——依赖 GNU 特有 flag 行为的脚本可能踩坑。 |
| **用 doas,不是 sudo** | `security.nix`:`security.sudo.enable`/`sudo-rs.enable` 都是 `false`,`security.doas.enable = true` | `pkgs.doas-sudo-shim` 让 `sudo` 命令实际走 doas,方便肌肉记忆,但 doas 不支持 sudo 的所有参数——脚本里硬编码了 sudo 专属参数的话会炸。 |
| **默认用加固版内存分配器** | `security.nix`:`environment.memoryAllocator.provider = "graphene-hardened-light"` | 拿一部分性能换加固。模块注释里提到了替代方案:`scudo`(均衡)、`mimalloc`(性能优先)。 |
| **好几个 daemon 用 musl + LibreSSL + clang 编译** | `core.nix`:unbound、chrony、openssh、wget;`proxy.nix`:dnscrypt-proxy、sing-box(都通过 `pkgsMusl`/`libressl`/`clangStdenv` override) | 攻击面更小、静态二进制——但这些不在标准二进制缓存里,机器上第一次构建得从源码编译。(`oci.nix` 也给自己的 nginx 套了同一层,不过那是主机级的 overlay,不是共用模块。) |
| **Unbound 在跑,但不一定是你的解析器** | `core.nix` 让 `services.unbound` 监听 `127.0.0.1`,但 `networking.nameservers` 默认直接指向 Cloudflare+Quad9——没有任何主机覆盖过这个值 | 默认情况下没有任何东西把系统 DNS 指向 unbound。只有开启 `modules.proxy` 时才会(`networking.networkmanager.insertNameservers = [ "127.0.0.1" ]`,挂在 `adguardhome`/`dnscrypt-proxy`/`singbox.dns` 后面)。不开代理的话,unbound 是在跑,但从系统角度看是闲置的。 |
| **WiFi 默认用 iwd——除了我自己的笔记本** | `desktop.nix`:`networking.networkmanager.wifi.backend = "iwd"`(`mkOverride 900`)——但 `omen15.nix` 用一次普通赋值把它改回了 `"wpa_supplicant"`,优先级更高,生效的是后者 | 连参考主机自己都没用模块里给的默认值(应该是驱动兼容性问题,仓库里没写明原因)。别因为模块默认是 iwd 就假设它一定适配你的 WiFi 网卡。 |
| **Geoclue(定位服务)默认开着** | `desktop.nix`:`services.geoclue2.enable = true`(`mkOverride 900`) | 跟 `privacy.nix` 里其他反指纹追踪的工作是拧着的——不自己关掉的话,应用是能申请到定位权限的。 |
| **桌面默认关掉了打印机/mDNS/移动网络发现** | `desktop.nix`:`services.printing.enable`、`services.avahi.enable`、`networking.modemmanager.enable` 都是 `false`(`mkOverride 900`) | 默认没有 CUPS 打印机自动发现,也没有 mDNS 的 `.local` 域名解析。 |
| **用 earlyoom,不是 systemd-oomd** | `performance.nix`:`systemd.oomd.enable = false`、`services.earlyoom.enable = true`(带一条 `--avoid` 正则保护游戏/Wine/Proton 进程) | 进程被意外 OOM kill 时,该查的是 `earlyoom` 的阈值/保护名单,不是 `oomd`。 |
| **chrony 开着,但从没显式关过 systemd-timesyncd** | `core.nix` 启用了 `services.chrony`(走 NTS 加密的服务器);没有任何地方设置 `services.timesyncd.enable = false` | nixpkgs 自己 `services.chrony.enable` 的选项说明写得很直白:"启用这个服务时请确保禁用 NTP"——建议在真实主机上查一下 `systemctl status systemd-timesyncd.service`,别想当然认为只有 chrony 在管时间。 |
| **`router.nix` 里的 `services.resolved.enable = false` 是防御性的,不是真的在覆盖什么** | `router.nix` 在它的 DHCP server 开启时用 `mkDefault` 设了这个值 | NixOS 自己默认就是关着 `services.resolved` 的——这行只是防止它在别处被打开,并没有关掉什么正在跑的东西。 |

---

## 我该怎么...

### ...在自己的 flake 里复用单个模块?

把这个 flake 加为 input,导入你想要的 `nixosModules.*`(完整列表见
[Reference](#可用的-nixosmodules)),再补上它需要的选项。大多数模块不需要额外
配置——下面这个只导入了一个:

```nix
# 你的 flake.nix
inputs.hydroakri-nixos.url = "github:hydroakri/dotfiles?dir=flake";

# 你的主机模块
{ inputs, ... }: {
  imports = [ inputs.hydroakri-nixos.nixosModules.security ];

  mainUser = "alice";                          # 默认值 "user" 不可用——必须自己设置
  modules.security.authorizedKeys = [
    "ssh-ed25519 AAAA... alice@laptop"
  ];
}
```

> `nixosModules.core` 是唯一的例外,因为它接了 `nix-index-database`,你的
> `lib.nixosSystem` 调用里需要传 `specialArgs = { inherit inputs; };`。不带
> `inputs` 参数的模块(大多数)不需要这个。

一次导入多个:

```nix
imports = [
  inputs.hydroakri-nixos.nixosModules.core        # 需要 specialArgs,见上
  inputs.hydroakri-nixos.nixosModules.security
  inputs.hydroakri-nixos.nixosModules.performance
];
modules.core.extraSubstituters = [ "https://nix-community.cachix.org" ];
modules.performance.vendor = "amd";               # 默认 "other" 会完全跳过微码
```

### ...新增或切换一台主机?

切换这个仓库自己的四台主机之一(在仓库根目录执行):

```bash
nh os switch -H omen15 ./flake
nh os switch -H oci ./flake
nh os switch -H rpi4-side-gateway ./flake
nh os switch -H rpi4-switch ./flake

# 只测试构建,不激活
nixos-rebuild build --flake ./flake#omen15
```

新增主机:创建 `flake/hosts/<name>/<name>.nix`,导入
`desktop.nix`/`server.nix` 中恰好一个(两个不能同时导入,见
[Reference](#可用的-nixosmodules) 里的 profile 说明),然后把它加进
`flake/flake.nix` 的 `nixosConfigurations`。不需要改别的——CI 构建矩阵是运行
时从 `nix eval .#githubActions.matrix` 生成的,新主机会自动被纳入。

### ...编辑或轮换 secrets?

```bash
# 在 flake/modules/features/secrets/ 下执行
sops secrets.yaml            # 所有主机共用的 secrets
sops proxy-secrets.yaml      # 只给 hydroakri + omen15 + rpi4(不含 oci)

# 改了 .sops.yaml 里的 recipients 之后
sops updatekeys secrets.yaml
```

Recipients 绑定在各主机的 SSH ed25519 host key 上——**重装前一定要备份
`/etc/ssh`**,不然这些 secrets 就永久解不开了。

### ...开启一个默认关闭的模块?

看 [Reference](#可用的-nixosmodules) 表格里的"配置路径"列——大多数功能模块
一旦导入就是常开的,但有一部分需要显式 `enable`:

```nix
modules.powersave.enable = true;
modules.preservation.enable = true;              # 不想用 /persistent 的话再加 persistentPath
modules.utils.enable = true;                      # enableGrafana/enablePrometheus/enableUptime 要分别开
modules.virtualisation.libvirtd.enable = true;    # KVM/QEMU + virt-manager
modules.proxy.enable = true;                       # singbox.enable / dae.enable / dnscrypt-proxy.enable 分别开
modules.router.enable = true;                       # 至少还要给 lan.interfaces
modules.networking.sqm.enable = true;
modules.networking.sysfsTuning.enable = true;
modules.nvidia.enable = true;                        # 混合显卡笔记本还要给 variant、amdgpuBusId/nvidiaBusId
modules.amd.rocm = true;
```

### ...用 home-manager 引导 CLI 工具集?

**任何**只装了 Nix 的 Linux 都能用——不限于我的 NixOS 主机(里面实际装了
什么见 [Reference](#home-manager)):

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
nix shell nixpkgs#git nixpkgs#chezmoi -c chezmoi init --apply https://github.com/hydroakri/dotfiles
nix run home-manager/master -- switch --flake ~/.config/home-manager#$USER --impure
nh home switch -- --impure   # 之后再切换(注意结尾的 --,不是开头的 flag)
```

⚠️ 它的 `flake.nix` 通过 `nixos-flake.url =
"github:hydroakri/dotfiles?dir=flake"` 锁定 `nixpkgs`——也就是说它跟的是*这个
仓库*的 nixpkgs,不是自己单独锁定的。如果你只想 fork 这一部分、不要 NixOS
flake,记得把这个 input 换成你自己的。

### ...应用或更新我的 dotfiles?

```bash
chezmoi diff                  # 预览改动
chezmoi apply                 # 部署到 $HOME
chezmoi apply ~/.config/niri  # 只应用单个目标
chezmoi update                 # 拉取 + 应用
```

命名约定:`dot_config/` → `~/.config/`、`executable_` → `+x`、`modify_` →
转换已有目标文件的脚本(比如 `modify_dot_gitconfig`,每次 apply 都会把 commit
签名配置块合并进 `~/.gitconfig`,不影响文件其余部分)。技术栈细节见
[Reference](#桌面技术栈)。

### ...解决已知的 dotfiles 坑?

1. **Hyprland 的快捷键不生效。** `dot_config/hypr/hyprland.conf` 里 exec 了
   `~/utils/bemenu`、`~/utils/rofi.sh`、`~/utils/gamemode.sh`——这些都没提交
   进 `utils/`(chezmoi 忽略,目前只有一个装着静态扩展设置备份的 `backup/`
   文件夹)。自己写这些脚本,或者干脆用 Niri——它没有这类引用,而且
   `flake/modules/desktop.nix` 在 NixOS 层本来也只开了 Niri。

2. **新机器上壁纸不显示。** 有两处互不相关的硬编码路径要改:
   `dot_config/noctalia/settings.json` 里 `"directory":
   "/home/hydroakri/Pictures/Wallpapers"`(Niri,靠 noctalia 轮换),以及
   `dot_config/hypr/hyprland.conf` 里那行没被注释掉的 `exec-once = swaybg -i
   ~/Pictures/wllppr/wall.jpg -m fill`(Hyprland,跟 noctalia 无关)。

3. **新机器或清空 `~/.zsh/` 后 shell 启动很慢。** 首次运行有两次阻塞式网络
   请求:antidote 的 `git clone --depth=1`,和 zsh-patina 通过 `curl`+`tar`
   拉取 release。这不是 bug,没法"修"——想跳过这次停顿就自己提前把
   `~/.antidote` 和 `~/.zsh/zsh-patina` 准备好。

4. **Git commit 没签名 / 签名显示未验证。** `modify_dot_gitconfig` 已经帮你
   设置好了 `commit.gpgsign = true` + `gpg.format = ssh`,但签名密钥还得同时
   存在于你的 GitHub 账号,以及目标主机的 sops `allowed_signers` 模板里——
   目前只给 `omen15` 接好了。

---

## Reference

### 仓库结构

```
flake/                  NixOS flake(多主机,声明式)
├── hosts/               各主机的入口文件 + personal-proxy-profile.nix
├── modules/              主机共用的模块
│   ├── core.nix            所有主机的基础层
│   ├── desktop.nix         桌面 profile(低延迟调优)
│   ├── server.nix          服务器 profile(吞吐量调优)
│   └── features/            按需开启的功能模块
└── templates/            开发环境模板(ros2)

dot_config/home-manager/  独立的 home-manager flake(可移植的 CLI 工具集)

dot_config/               其余部分都是 chezmoi 管理 → ~/.config/
dot_local/                 → ~/.local/(Flatpak 覆盖、KDE Flexoki 配色)
dot_var/                   → ~/.var/(VSCodium Flatpak 配置)
dot_zshrc                  → ~/.zshrc
modify_dot_gitconfig        → ~/.gitconfig(注入 commit 签名配置块)
utils/                    脚本(chezmoi 不部署,目前只有 backup/ 一个静态导出的
                           扩展设置备份文件夹)
```

`flake/` 和 `utils/` 通过 `.chezmoiignore` 排除在 chezmoi 部署之外(该文件也
排除了所有 `*.md`,所以这份文档本身不会被拷进 `$HOME`)。

### 主机

| 主机 | 架构 | Profile | 角色 |
|------|------|---------|------|
| `omen15` | x86_64 | desktop | 主力笔记本(AMD + NVIDIA 双显卡,锁定 CachyOS 内核) |
| `oci` | aarch64 | server | Oracle Cloud——vaultwarden、searx、atticd、headscale、一个 Minecraft 服务器,nginx 反代若干 `*.hydroakri.cc` 子域 |
| `rpi4-side-gateway` | aarch64 | server | 树莓派 4——透明代理(sing-box + dnscrypt-proxy + dae),不管 DHCP/NAT |
| `rpi4-switch` | aarch64 | server | 树莓派 4——局域网路由:DHCP、NAT、SQM,不跑代理栈 |

还有两个 flake package 构建的是独立镜像,不是主机配置:
`packages.x86_64-linux.iso-installer`(图形化 Calamares 安装器 ISO)和
`packages.aarch64-linux.rpi-image`(引导用 SD 卡镜像——里面的 wifi 密码和 root
密码都是占位符,刷机前记得改 `flake/hosts/rpi-image/`)。

两个 profile 模块互斥——每台主机只能选一个,没有 `assertions` 强制约束,纯靠
主机文件自律:[`desktop`](flake/modules/desktop.nix)(`preempt=full`)或
[`server`](flake/modules/server.nix)(`preempt=voluntary`)。

### 可用的 `nixosModules`

| 名称 | 说明 | 配置路径 | 复用须知 |
|------|------|--------------|-------------|
| [`core`](flake/modules/core.nix) | Nix 设置/额外缓存、Unbound DNS、Chrony NTS、终端工具、SMART 监控。还会带入 `sqm.nix`/`tuning.nix`(默认关闭)。 | 常开;`modules.core.extraSubstituters`/`extraTrustedPublicKeys` | 需要 `specialArgs={inherit inputs;}`。硬编码了 DNS(Cloudflare+Quad9)和 GitHub 走 443 的 SSH 路由,这两个是普通默认值,不是 option。 |
| [`desktop`](flake/modules/desktop.nix) | `preempt=full`、PipeWire、XDG portals、`hardware.graphics`(Vulkan/OpenGL/OpenCL)、fcitx5、用 nixpak 沙箱跑 Brave/Mullvad Browser。这里只有 Niri 真正接了 `programs.*.enable`。 | 常开 | — |
| [`server`](flake/modules/server.nix) | `preempt=voluntary`、tuned、fail2ban、irqbalance、抗 bufferbloat 的 sysctl。 | 常开 | — |
| [`performance`](flake/modules/features/performance.nix) | BBR+CAKE、MGLRU/zram、scx 调度器、I/O 调度器 udev 规则、厂商微码。 | 常开;`modules.performance.vendor` | 默认 `"other"` 会跳过微码——记得显式设置。 |
| [`security`](flake/modules/features/security.nix) | 内核加固、AppArmor、doas、FIDO2 SSH/PAM、USBGuard、sysctl 基线(无桌面主机还有一段更严格的覆盖)。 | 常开;`modules.security.authorizedKeys`/`u2fMappings` | ⚠️ 两个都默认空——不设置的话 root SSH 登录和 u2f PAM 实际上是关闭的。 |
| [`privacy`](flake/modules/features/privacy.nix) | 反指纹追踪:Brave 加固策略、kloak 键鼠时序匿名化、MAC/IPv6 隐私地址、Unbound RPZ 屏蔽名单 + DoT 上游。 | 常开 | 上游都是公共解析器(Quad9/Cloudflare/AdGuard/Mullvad/Control D),不是个人端点。 |
| [`powersave`](flake/modules/features/powersave.nix) | 省电内核参数、激进的 PCIe ASPM、按交流电/电池切换的 udev 规则,优化 s2idle 效率。 | 按需:`modules.powersave.enable` | — |
| [`gaming`](flake/modules/features/gaming.nix) | scx_lavd 调度器、Gamescope、GameMode、Steam 防火墙端口。导入它不会自动开 Steam——`programs.steam.enable` 默认还是 `false`。 | 常开(Steam 需单独开启) | — |
| [`preservation`](flake/modules/features/preservation.nix) | 根目录 tmpfs + preservation 状态持久化(NetworkManager、Unbound/Chrony 状态、SSH host key、machine-id、大部分 `/var/lib/*`)。 | 按需:`modules.preservation.enable`/`persistentPath` | 给已有数据的主机加这个模块,得先手动 `rsync` 一次——preservation 不会帮你搬数据。 |
| [`utils`](flake/modules/features/utils.nix) | Prometheus + node-exporter、Grafana、Uptime Kuma,外加 `enableGraphicTools`(GPU 诊断工具:nvtop、vulkan-tools、clinfo……)。 | 按需:`modules.utils.enable` + `enableGrafana`/`enablePrometheus`/`enableUptime`/`enableGraphicTools` | Grafana 需要一个 `grafana_secret_key` sops secret——自己准备。*这里没有配置 Glance*——`oci` 上 `glance.hydroakri.cc` 那个 vhost 只是个裸的 nginx 反代,指向一个 Nix 里哪儿都没声明的服务(带外运行)。 |
| [`virtualisation`](flake/modules/features/virtualisation.nix) | Podman + Docker 兼容层、aarch64 binfmt 模拟(两者都常开)。 | KVM/QEMU+libvirtd 按需:`modules.virtualisation.libvirtd.enable` | — |
| [`networking-proxy`](flake/modules/features/networking/proxy.nix) | sing-box(FakeIP/TUN)+ dnscrypt-proxy + AdGuardHome + dae eBPF 透明代理。 | 按需:`modules.proxy.enable`(还有一堆子开关) | 是真的按可复用来设计的——所有 secret/端点都是扩展点(`extraEndpoints`、`outboundsFile`、sing-box 原生的 `_secret` 标记……),模块本身**不带**任何个人解析器或端点数据。我自己的身份信息通过没有导出的 `flake/hosts/personal-proxy-profile.nix` 单独提供。 |
| [`networking-router`](flake/modules/features/networking/router.nix) | NAT 路由:VLAN、DHCP(dnsmasq)、MSS clamping、放松反向路径过滤。 | 按需:`modules.router.enable` | — |
| [`networking-sqm`](flake/modules/features/networking/sqm.nix) | 通过 `tc` 做 CAKE SQM,借 NetworkManager 的 dispatcher 脚本触发。 | 按需:`modules.networking.sqm.enable` | 已经被 `core` 带入(默认关闭)——大多数主机不需要直接导入。 |
| [`networking-tuning`](flake/modules/features/networking/tuning.nix) | sysfs 网卡调优:RPS/XPS CPU 亲和性。 | 按需:`modules.networking.sysfsTuning.enable` | 已经被 `core` 带入。 |
| [`hardware-amd`](flake/modules/hardware/amd.nix) | AMD 显卡:常开 `hardware.amdgpu.overdrive` + `services.lact`;ROCm 按需。 | ROCm 按需:`modules.amd.rocm` | 不配置 zenpower——那是每台主机自己手搭的(见 `omen15.nix` 的 `boot.extraModulePackages`)。 |
| [`hardware-nvidia`](flake/modules/hardware/nvidia.nix) | NVIDIA 驱动(通过 `variant` 选 open/proprietary/nouveau),给 AMD+NVIDIA 混合显卡笔记本用的 PRIME offload。 | 按需:`modules.nvidia.enable`/`variant` | 总线 ID 默认是我笔记本的(`PCI:7@0:0:0` / `PCI:1@0:0:0`)——按你自己的硬件改。 |
| [`filesystem-btrfs`](flake/modules/filesystems/btrfs.nix) | `services.btrfs.autoScrub`、每月 balance 定时器、`/` 和 `/home` 每小时 Snapper 快照。 | 常开 | 不设置子卷布局/挂载选项——参见 `flake/hosts/omen15/disko.nix`,目前唯一的使用者。 |

下面这些模块存在但故意没有导出:`flake/modules/features/agent.nix`(Hermes
Agent / llama.cpp——里面硬编码了一个私人 Telegram 用户 ID,只有 `omen15` 直接
导入它)和 `flake/modules/features/secrets/secrets.nix`(把 sops 绑定到我各主机
的 SSH host key 上)。

### 关键选项

**`mainUser`** *(字符串,默认 `"user"`)* ⚠️ ——系统用户名,模块里到处用它算
home 路径、组、PAM。默认值故意是不可用的。

**`modules.core.extraSubstituters`/`extraTrustedPublicKeys`** *(列表,默认
`[]`)* ——追加在 `cache.nixos.org` + `nix-community.cachix.org` 之后的二进制
缓存。我的主机在这里加了 `cache.hydroakri.cc`;你会加你自己的。

**`modules.security.authorizedKeys`** *(列表,默认 `[]`)* ⚠️ ——授权 root 登录
的 SSH 公钥。空值意味着 root SSH 是关闭的。

**`modules.security.u2fMappings`** *(多行字符串,默认 `""`)* ⚠️ ——
`/etc/u2f_mappings` 的内容,来自 `pamu2fcfg -n`。空值完全关闭 u2f PAM。

**`modules.performance.vendor`** *(枚举 `amd`\|`intel`\|`other`,默认
`"other"`)* ——选微码包。`"other"` 会跳过微码。

### 常用命令

```bash
nix flake check ./flake        # 对四台主机做求值检查,不构建(便宜的正确性检查)
nix fmt ./flake                 # nixfmt + statix + deadnix(配置内联,走 treefmt-nix)
nix flake update --flake ./flake

nix build ./flake#packages.x86_64-linux.iso-installer
nix build ./flake#packages.aarch64-linux.rpi-image

nix flake init -t 'github:hydroakri/dotfiles?dir=flake#ros2'   # 在别处初始化 ROS2 开发环境
```

<a id="ci-build-pipeline"></a>

### CI / 构建流水线

| Job / 工作流 | 触发条件 | 做什么 |
|---|---|---|
| `ci.yml` → `check` | push/PR 到 `flake/**` 或 `dot_config/home-manager/**`,每晚,手动 | `nix flake check` |
| `ci.yml` → `nix-matrix` | 同上 | 从 `nix eval .#githubActions.matrix` 生成构建矩阵(`nix-github-actions`)——加减主机不用手改工作流 |
| `ci.yml` → `build` | 同上 | 在 x86_64/aarch64 runner 上矩阵构建四台主机的 `nixosConfigurations.*.toplevel`,推到 `cache.hydroakri.cc`(自建 Attic)+ 备用的"LanTian"缓存;x86_64 runner 会先清盘、加 8G swap,应付从源码构建 clang 的开销 |
| `ci.yml` → `home-manager-build` | 同上 | 单独构建独立 home-manager flake 的 activation package,跟四主机矩阵无关 |
| `update-flake-lock.yml` | 每天定时,手动 | 只有内核 hash 真的变了、且 NixOS Hydra channel 健康时才更新 `flake/flake.lock`,然后自动合并 |
| `update-home-manager-lock.yml` | 每天定时,比上面晚 2 小时 | 更新 `dot_config/home-manager/flake.lock`(跟的是 `flake/` 的 nixpkgs,自己没单独锁定);自动合并 |

> 如果你把这个 flake 当 input 用,建议把 `cache.hydroakri.cc` 加进
> `modules.core.extraSubstituters`——CI 一直在往里推预构建产物。

### Home Manager

`dot_config/home-manager/` 是它自己的一个 flake——只管 CLI 工具(zsh、neovim、
tmux、zellij、fzf、bat、atuin、zoxide、lazygit、ripgrep、starship……),用裸
的 `home.packages` 而不是 `programs.zsh`/`git`/`neovim`,这样就不会跟 chezmoi
抢 `~/.zshrc`、`~/.config/git`、`~/.config/nvim`。

### 桌面技术栈

- **窗口合成器**:Hyprland、Niri、Sway 的配置目录都存在——但
  `flake/modules/desktop.nix` 只设置了 `programs.niri.enable`;Hyprland 和
  Sway 在这里没有接到任何 NixOS 层面的 enable 选项。
- **Shell**:zsh 是声明的登录 shell(`core.nix` 给 root 和 `mainUser` 都设了),
  通过 **antidote** 加 **zsh-patina** 做语法高亮来引导。还有一份更轻量的
  **fish** 配置,但没被设成任何人的登录 shell。
- **终端**:WezTerm、Ghostty。
- **主题**:明暗切换完全由 `darkman` 通过 `gsettings` 驱动——Nix 里不写死
  任何主题值。`desktop.nix` 把 `adw-gtk3`/`qt6ct`/`qt5ct`/`darkman`/`darkly`
  当系统包装进去;Niri 的 shell/状态栏是 **noctalia-shell**,壁纸轮换也是
  它管的。
- **输入法**:Fcitx5 + rime-wanxiang,由 `desktop.nix` 以 Nix 包的形式提供
  (不走 chezmoi)。
- **外部插件管理器**:`.chezmoiexternal.toml` 把 tmux 的 TPM 拉到
  `~/.tmux/plugins/tpm`;zsh 插件走 antidote。

---

## License

[MIT](LICENSE) ——欢迎 fork 和魔改。
