# Prism Launcher / Minecraft 26.3-alpha: Iris 启动崩溃（SDL + EGL）——workaround 记录

记录日期：2026-10-22

应用层的 flatpak workaround；本仓库不做部署，东西都放在 Prism flatpak 自己
的 app-data 里。记录在此是因为该修复与两个会变的东西绑在一起：NVIDIA
flatpak GL 扩展版本和 niri 的 Wayland 协议覆盖情况（见下文
[维护触发点](#维护触发点)）。

## 环境

| 组件 | 内容 |
| ---- | ---- |
| 宿主机 | `omen15`（NixOS），niri 26.04（缺 `fifo-v1`），NVIDIA 595.104.02（RTX 3060 Laptop）+ AMD Cezanne 核显 |
| 启动器 | Prism Launcher 11.1.1（flatpak `org.prismlauncher.PrismLauncher`，runtime `org.kde.Platform` 6.10） |
| GL 扩展 | `org.freedesktop.Platform.GL.nvidia-595-104-02` |
| 游戏 | MC 26.3-alpha（renderpearl + SDL3，mod `dev_isxander_sdl_sdl-backend-ffm release-3.4.14-7`），Iris 1.11.7+mc26.3，Sodium |
| Java | Prism 自带 `java-runtime-epsilon`（Java 25.0.1） |

不受影响的对照组：MC 26.2 系的 Sodium + Iris 一直正常启动，本次改动对它
零影响（env 是 per-instance 的，见[拆除](#拆除)）。

## 症状

启动时以退出码 6 结束，死在后端初始化。`instances/26.3-alpha/minecraft/logs/latest.log`：

```
[Render thread/INFO]: SDL [VIDEO]: This compositor lacks support for the fifo-v1 protocol; falling back to XWayland for GPU performance reasons (set SDL_VIDEO_DRIVER=wayland to override)
[Render thread/INFO]: SDL [VIDEO]: Detected XWayland
[Render thread/ERROR]: Failed to create backend OpenGL
com.mojang.renderpearl.api.device.BackendCreationException: OpenGL is not supported: Could not retrieve OpenGL functions
```

不装 Iris 时游戏照样能跑（renderpearl 静默回退到 Vulkan 后端）；装了 Iris
就会 abort —— Iris 只支持 OpenGL，会在已初始化成 Vulkan 的上下文里去查 GL
函数 → LWJGL `No context is current` → 退出码 6。`options.txt` 里
`preferredGraphicsBackend:"opengl"` 只表达游戏自己的偏好，不影响 SDL 的初始
化路径。

## 根因链（三道各自独立的关卡）

1. **SDL3 的视频后端选择。** renderpearl 的 SDL 会探测 Wayland compositor
   能力，发现缺 `fifo-v1`，就以"GPU 性能"为由回退 XWayland——不管 env
   怎么设（失败的那些测试里 env 根本没到游戏进程，见
   [没走通的注入路径](#没走通的注入路径)）。
2. **回退路径下的 GL 加载。** Wayland 会话里 LWJGL 递给 SDL 的是 EGL 库
   路径，而 XWayland/X11 驱动按 GLX 语义找库 → `SDL_GL_LoadLibrary` 失败
   → `Could not retrieve OpenGL functions`。用 `SDL_VIDEO_DRIVER=wayland`
   （强制原生 Wayland）解。
3. **GLVND 的 EGL vendor 解析。** 强制原生 Wayland 后崩溃往深一层挪：沙盒
   里 glvnd 默认搜索路径上没有 NVIDIA EGL vendor json，且沙盒的
   `LD_LIBRARY_PATH` 不含扩展的 lib 目录 → `eglChooseConfig` 报
   `EGL_BAD_DISPLAY`（`GlDevice.<init>(GlDevice.java:109)`："Couldn't find
   matching EGL config"）。用显式指定 vendor json + 绝对
   `library_path`（见下文）解。`__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS` 已经
   解析到 NVIDIA 的 external-platform 配置（符号链接在
   `/usr/lib/x86_64-linux-gnu/GL/egl/egl_external_platform.d/`），无需额外动作。
4. **NVIDIA 线程优化。** 该驱动家族的已知崩溃源 → `__GL_THREADED_OPTIMIZATIONS=0`（与 Iris #3336 一致）。

为什么 ≤26.2 版本没事：renderpearl 之前的 MC 只有一条固定路径
（GLFW → X11/XWayland → GLX）。没有"选后端"这一步、没有 Vulkan 回退、也
没有原生 Wayland 的 EGL vendor 解析——协议探测、静默回退、vendor 解析
这些坑在旧栈里根本不存在。

## 修复

三条 per-instance 环境变量（Prism GUI → 编辑 `26.3-alpha` 实例 →
**Environment Variables** 选项卡，记得勾上该选项卡顶部的 **Override**
开关），外加一个小 JSON 文件：

```
SDL_VIDEO_DRIVER=wayland
__EGL_VENDOR_LIBRARY_FILENAMES=/home/hydroakri/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/10_nvidia_flatpak.json:/home/hydroakri/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/50_mesa_flatpak.json
__GL_THREADED_OPTIMIZATIONS=0
```

`~/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/10_nvidia_flatpak.json`
（内容与扩展自带的 vendor json 相同，仅把 `library_path` 改成绝对路径）：

```json
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "/usr/lib/x86_64-linux-gnu/GL/nvidia-595-104-02/lib/libEGL_nvidia.so.0"
    }
}
```

- json 放在 Prism flatpak 的 app-data 里，因为 `~/.config` **没有**挂进
  这个应用的沙盒（permissions 只共享了特定路径），而 app-data 目录永远在。
- `library_path` 用绝对路径，绕开沙盒里扩展 lib 目录缺失的
  `LD_LIBRARY_PATH` 条目（glvnd 直接按 json 里的路径 dlopen）。

`~/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/50_mesa_flatpak.json`
（Mesa 的 vendor json，`library_path` 同样写绝对路径，不随 NVIDIA 驱动版本变）：

```json
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "/usr/lib/x86_64-linux-gnu/GL/default/lib/libEGL_mesa.so.0"
    }
}
```

- 两个 json 必须同时 pin。只 pin NVIDIA 时 `eglGetDisplay` 失败
  （2026-10-28：`Could not get EGL display`，随后 Vulkan 后端也报
  `VK_KHR_surface` 缺失）。机器是 AMD Cezanne 核显 + RTX 3060 双显卡，
  SDL 取默认 display 时要能回落到 Mesa；NVIDIA 在 Wayland 上只接受显式
  platform。
- NVIDIA 排在前面，保证上下文仍建在独显上。

修复后 `latest.log` 的验证：

```
[Render thread/INFO]: Using graphics backend OpenGL, using drivers: 3.3.0 NVIDIA 595.104.02
[Render thread/INFO]: Sound engine started
```

持久化：这三条由 Prism 自己写回
`instances/26.3-alpha/instance.cfg` 的 `Env="{...}"` + `OverrideEnv=true`
（设置键 `Env`，默认 `"{}"`，启动时经
`MinecraftInstance::createEnvironment()` → `insertEnv(...)` 读取，JSON map）。

## 没走通的注入路径

2026-10-22 的实测结果，记录下来避免以后重新推导：

- `flatpak override --user --env=…` / `flatpak run --env=…`：变量从未出现
  在游戏进程的 environ 里（`/proc/<pid>/environ` 已验证），尽管启动器源码
  的 `CleanEnviroment()` 理论上会透传未知变量。机制没有完全钉死——总之，
  走 Prism 自己的 Environment Variables 设置注入，别走 flatpak。
- 在 Prism **运行期间**手写 `instance.cfg`（`Env=…`，或
  `OverrideCommands=true` + `WrapperCommand=env …`）：启动器退出时被静默
  丢弃；wrapper 从未执行（游戏 java 的父进程是启动器，不是 `env`）。
  Prism **已退出**时改 `Env=…`，再用 `flatpak run
  org.prismlauncher.PrismLauncher --launch 26.3-alpha` 启动：值会到达游戏
  进程（2026-10-28，`/proc/<pid>/environ` 已验证）。改后是否在下次退出时被
  保留未测。
- 全局 `prismlauncher.cfg` 的 `WrapperCommand=env …`：同样从未执行（事后已移除）。
- 早期假设"SDL 无视 `SDL_VIDEO_DRIVER=wayland` env override"是错的：那些
  测试里 env 根本没到游戏。

有意保持不动：Prism Tweaks 里 `Use discrete GPU` + `Use Zink` 均开启。它们
会注入 `DRI_PRIME=1`、`__NV_PRIME_RENDER_OFFLOAD=1`、
`__VK_LAYER_NV_optimus=NVIDIA_only`、`__GLX_VENDOR_LIBRARY_NAME=mesa`、
`MESA_LOADER_DRIVER_OVERRIDE=zink`、`GALLIUM_DRIVER=zink`；修好后游戏仍报
`3.3.0 NVIDIA 595.104.02`，与本修复无冲突。

## 维护触发点

1. **NVIDIA GL 扩展版本升级**（flatpak 扩展随宿主驱动更新）：json 里写死
   的绝对路径 `nvidia-595-104-02/…` 失效 → 第 3 关再次报
   `EGL_BAD_DISPLAY`。重新生成 json（见
   [自愈脚本](#可选自愈脚本已设计未部署)）。
2. **拆除时机**：niri 支持 `fifo-v1`，或 Mojang / Iris 修好他们那边（原生
   Wayland 下 OpenGL 开箱即用）之后——当前这个 bug 链在上游：
   IrisShaders/Iris#3345 / IrisShaders/Iris#3336 / MC-311954。

### 拆除

1. Prism GUI → 实例 `26.3-alpha` → Edit → Environment Variables → 删掉三条
   （或关掉选项卡的 Override）。
2. `rm -rf ~/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/`

现场清理备注（2026-10-22）：排错期间加的 `flatpak override` env 已回滚；
`~/.local/share/flatpak/overrides/org.prismlauncher.PrismLauncher` 只保留
原有的 `[Context]` 条目。

## 可选自愈脚本（已设计，未部署）

对当前挂载的最新 NVIDIA GL 扩展重新生成 vendor json；建议在
`nixos-rebuild` / NVIDIA 驱动更新后运行：

```bash
#!/usr/bin/env bash
set -euo pipefail
inner='ls -1 /usr/lib/x86_64-linux-gnu/GL/ | grep -E "^nvidia-[0-9]+-[0-9]+-[0-9]+$" | sort -V | tail -1 | sed "s/^nvidia-//; s/-/./g"'
ver="$(flatpak run --command=sh org.prismlauncher.PrismLauncher -c "$inner")"
lib="/usr/lib/x86_64-linux-gnu/GL/nvidia-${ver//./-}/lib/libEGL_nvidia.so.0"
dst="$HOME/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/10_nvidia_flatpak.json"
mkdir -p "$(dirname "$dst")"
printf '{\n    "file_format_version" : "1.0.0",\n    "ICD" : {\n        "library_path" : "%s"\n    }\n}\n' "$lib" > "$dst"
printf 'wrote %s (driver %s)\n' "$dst" "$ver"
```

若要正式落地本仓库：`dot_local/bin/executable_prism-mc-regen-egl-vendor`
（chezmoi 命名），手动运行或挂钩 rebuild 通知。截至本文撰写尚未部署。

## 参考

- IrisShaders/Iris#3345 —— 26.x 上的启动崩溃 + `SDL_VIDEO_DRIVER=wayland` workaround，指向 Mojang MC-311954
- IrisShaders/Iris#3336 —— NVIDIA 专属 env 组合（`__EGL_VENDOR_LIBRARY_FILENAMES`、`__GL_THREADED_OPTIMIZATIONS=0` 等）
- Mojang MC-311954 —— 新渲染栈里 fifo-v1 / XWayland 回退行为
