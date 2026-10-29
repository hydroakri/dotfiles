# Prism Launcher / Minecraft 26.3-alpha: Iris launch crash (SDL + EGL) — workaround notes

Recorded: 2026-10-22

App-level flatpak workaround; nothing here is deployed from this repo. The
pieces live in the Prism flatpak's own app-data. Recorded because the fix is
coupled to two moving parts: the NVIDIA flatpak GL extension version and
niri's Wayland protocol coverage (see [Maintenance triggers](#maintenance-triggers)).

## Environment

| Component | Value |
| --------- | ----- |
| Host | `omen15` (NixOS), niri 26.04 (lacks `fifo-v1`), NVIDIA 595.104.02 (RTX 3060 Laptop) + AMD Cezanne iGPU |
| Launcher | Prism Launcher 11.1.1 (flatpak `org.prismlauncher.PrismLauncher`, runtime `org.kde.Platform` 6.10) |
| GL extension | `org.freedesktop.Platform.GL.nvidia-595-104-02` |
| Game | MC 26.3-alpha (renderpearl + SDL3 via mod `dev_isxander_sdl_sdl-backend-ffm release-3.4.14-7`), Iris 1.11.7+mc26.3, Sodium |
| Java | Prism bundled `java-runtime-epsilon` (Java 25.0.1) |

Reference combo that stays fine: MC 26.2-era Sodium + Iris launches normally
and is not affected by any of this (the env vars are per-instance, see
[Removal](#removal)).

## Symptom

Launch exits with code 6 during backend init. `instances/26.3-alpha/minecraft/logs/latest.log`:

```
[Render thread/INFO]: SDL [VIDEO]: This compositor lacks support for the fifo-v1 protocol; falling back to XWayland for GPU performance reasons (set SDL_VIDEO_DRIVER=wayland to override)
[Render thread/INFO]: SDL [VIDEO]: Detected XWayland
[Render thread/ERROR]: Failed to create backend OpenGL
com.mojang.renderpearl.api.device.BackendCreationException: OpenGL is not supported: Could not retrieve OpenGL functions
```

Without Iris the game still launches (renderpearl silently falls back to the
Vulkan backend); with Iris it aborts — Iris is OpenGL-only and queries GL
functions in the Vulkan-initialized context → LWJGL `No context is current`
→ exit 6. `options.txt` had `preferredGraphicsBackend:"opengl"` but that
only steers the game's own preference, not the SDL init path.

## Root cause chain (three independent gates)

1. **SDL3 video backend selection.** renderpearl's SDL probes the Wayland
   compositor, misses `fifo-v1`, and falls back to XWayland "for GPU
   performance reasons" regardless of the env override (the env simply never
   reached the game in the failing tests, see
   [Injection paths that do NOT work](#injection-paths-that-do-not-work)).
2. **GL loading under the fallback.** LWJGL in a Wayland session hands SDL
   an EGL library path while the XWayland/X11 driver expects GLX semantics →
   `SDL_GL_LoadLibrary` fails → `Could not retrieve OpenGL functions`.
   Unblocked by `SDL_VIDEO_DRIVER=wayland` (forces native Wayland).
3. **GLVND EGL vendor resolution.** With native Wayland the crash moves one
   gate deeper: the sandbox has no NVIDIA EGL vendor json on glvnd's default
   search paths, and its `LD_LIBRARY_PATH` does not include the extension's
   lib dir → `eglChooseConfig` fails with `EGL_BAD_DISPLAY`
   (`GlDevice.<init>(GlDevice.java:109)`: "Couldn't find matching EGL
   config"). Unblocked by an explicitly pointed vendor json with an absolute
   `library_path` (below). `__EGL_EXTERNAL_PLATFORM_CONFIG_DIRS` already
   resolves NVIDIA's external-platform configs (symlinked under
   `/usr/lib/x86_64-linux-gnu/GL/egl/egl_external_platform.d/`), no extra
   action there.
4. **NVIDIA threaded optimizations.** Known crash source on this driver
   family → `__GL_THREADED_OPTIMIZATIONS=0` (matches Iris #3336).

Why versions ≤26.2 are unaffected: pre-renderpearl MC uses one fixed path
(GLFW → X11/XWayland → GLX). There is no backend-selection step, no Vulkan
fallback, and no native-Wayland EGL vendor dance at all — the protocol
probe, the silent fallback, and the vendor resolution simply do not exist
on the old stack.

## Fix

Three per-instance environment variables (Prism GUI → edit
`26.3-alpha` instance → **Environment Variables** tab, with the tab's
**Override** toggle on) plus one small JSON file:

```
SDL_VIDEO_DRIVER=wayland
__EGL_VENDOR_LIBRARY_FILENAMES=/home/hydroakri/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/10_nvidia_flatpak.json:/home/hydroakri/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/50_mesa_flatpak.json
__GL_THREADED_OPTIMIZATIONS=0
```

`~/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/10_nvidia_flatpak.json`
(same as the extension's own vendor json, re-hosted with `library_path` made absolute):

```json
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "/usr/lib/x86_64-linux-gnu/GL/nvidia-595-104-02/lib/libEGL_nvidia.so.0"
    }
}
```

- The json lives inside the Prism flatpak's app-data because `~/.config`
  is **not** mounted into this app's sandbox (permissions share only select
  paths); the app-data dir always is.
- The absolute `library_path` bypasses the sandbox's missing
  `LD_LIBRARY_PATH` entry for the extension lib dir (glvnd dlopens the path
  straight from the json).

`~/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/egl_vendor.d/50_mesa_flatpak.json`
(Mesa vendor json, absolute `library_path`, independent of the NVIDIA driver version):

```json
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "/usr/lib/x86_64-linux-gnu/GL/default/lib/libEGL_mesa.so.0"
    }
}
```

- Both jsons must be pinned. With only NVIDIA pinned, `eglGetDisplay` fails
  (2026-10-28: `Could not get EGL display`, then the Vulkan backend fails
  with missing `VK_KHR_surface`). The machine is AMD Cezanne iGPU + RTX 3060,
  SDL's default display needs a Mesa fallback; NVIDIA on Wayland only
  accepts an explicit platform.
- NVIDIA is listed first so the context is still created on the dGPU.

Verified `latest.log` after the fix:

```
[Render thread/INFO]: Using graphics backend OpenGL, using drivers: 3.3.0 NVIDIA 595.104.02
[Render thread/INFO]: Sound engine started
```

Persistence: Prism itself writes the values into
`instances/26.3-alpha/instance.cfg` as `Env="{...}"` + `OverrideEnv=true`
(setting key `Env`, default `"{}"`, read at launch via
`MinecraftInstance::createEnvironment()` → `insertEnv(...)`, JSON map).

## Injection paths that do NOT work

Empirical results from 2026-10-22, recorded to save re-derivation:

- `flatpak override --user --env=…` / `flatpak run --env=…`: the values
  never appeared in the game process environ (verified via
  `/proc/<pid>/environ`) even though the launcher source's
  `CleanEnviroment()` passes unknown vars through. Mechanism not fully
  pinned down — either way, inject through Prism's own Environment
  Variables setting, not flatpak.
- Hand-editing `instance.cfg` (`Env=…`, or `OverrideCommands=true` +
  `WrapperCommand=env …`) **while Prism is running**: silently discarded when
  the launcher exits; the wrapper never executed (the game java's parent
  process was the launcher, not `env`). Editing `Env=…` **after Prism has
  exited**, then launching with `flatpak run org.prismlauncher.PrismLauncher
  --launch 26.3-alpha`: the values reach the game process (2026-10-28,
  verified via `/proc/<pid>/environ`). Whether they survive the next exit is
  untested.
- Global `prismlauncher.cfg` `WrapperCommand=env …`: never executed either
  (removed afterwards).
- The earlier hypothesis "SDL ignores the `SDL_VIDEO_DRIVER=wayland` env
  override" was wrong: in those tests the env simply never reached the
  game.

Left untouched on purpose: Prism Tweaks `Use discrete GPU` + `Use Zink`
both enabled. They inject `DRI_PRIME=1`, `__NV_PRIME_RENDER_OFFLOAD=1`,
`__VK_LAYER_NV_optimus=NVIDIA_only`, `__GLX_VENDOR_LIBRARY_NAME=mesa`,
`MESA_LOADER_DRIVER_OVERRIDE=zink`, `GALLIUM_DRIVER=zink`; the fixed game
still reports `3.3.0 NVIDIA 595.104.02`, so no conflict with the fix.

## Maintenance triggers

1. **NVIDIA GL extension version bump** (flatpak extension updates follow
   host driver updates): the absolute path `nvidia-595-104-02/…` in the json
   dangles → back to `EGL_BAD_DISPLAY` at gate 3. Regenerate the json (see
   [Self-healing script](#optional-self-healing-script-designed-not-deployed)).
2. **Removal becomes appropriate** when niri gains `fifo-v1`, or
   Mojang/Iris fix their side (native Wayland OpenGL working out of the
   box) — the current bug chain is upstream: IrisShaders/Iris#3345 /
   IrisShaders/Iris#3336 / MC-311954.

### Removal

1. Prism GUI → instance `26.3-alpha` → Edit → Environment Variables →
   delete the three entries (or toggle the tab's Override off).
2. `rm -rf ~/.var/app/org.prismlauncher.PrismLauncher/data/glvnd/`

Session cleanup note (2026-10-22): the `flatpak override` envs added during
debugging were reverted; `~/.local/share/flatpak/overrides/org.prismlauncher.PrismLauncher`
keeps only its pre-existing `[Context]` entries.

## Optional self-healing script (designed, NOT deployed)

Regenerates the vendor json against the newest mounted NVIDIA GL extension;
intended to run after `nixos-rebuild` / NVIDIA driver updates:

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

If it should live in this repo: `dot_local/bin/executable_prism-mc-regen-egl-vendor`
(chezmoi naming), run manually or hook into a rebuild notification. Not
deployed as of this writing.

## References

- IrisShaders/Iris#3345 — launch crash on 26.x + `SDL_VIDEO_DRIVER=wayland` workaround, pointer to Mojang MC-311954
- IrisShaders/Iris#3336 — NVIDIA-specific env bundle (`__EGL_VENDOR_LIBRARY_FILENAMES`, `__GL_THREADED_OPTIMIZATIONS=0`, …)
- Mojang MC-311954 — fifo-v1 / XWayland fallback behavior in the new render stack
