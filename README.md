# hydroakri's NixOS & Dotfiles

> Multi-host NixOS flake + Chezmoi dotfiles for Wayland desktops and ARM servers.

This repo bundles two independent, loosely-coupled things: a multi-host NixOS
flake (`flake/` — declarative machine provisioning) and a set of chezmoi-managed
dotfiles (everything else — Wayland desktop session config). They share a
directory but not code: `flake/` and `utils/` are excluded from chezmoi
deployment via `.chezmoiignore`, and the dotfiles aren't NixOS-specific. Jump to
[NixOS Flake](#nixos-flake) or [Dotfiles (Chezmoi)](#dotfiles-chezmoi).

## ⚠️ Warning

**This is my personal configuration. Do not use it blindly.**

Keys, secrets, hardware IDs, and domain names are mine. The modules are designed
to be reusable — see [Using as a Flake Input](#using-as-a-flake-input) — but you
must supply your own values for everything under `modules.security` and `mainUser`.

## Repository Structure

```
flake/          NixOS flake (multi-host, declarative)
├── hosts/      Per-machine entry points
├── modules/    Shared modules imported by hosts
│   ├── core.nix          Base layer for all hosts
│   ├── desktop.nix       Desktop profile (latency-tuned)
│   ├── server.nix        Server profile (throughput-tuned)
│   └── features/         Opt-in capabilities
└── templates/  Dev-shell templates (ros2)

dot_config/     Chezmoi-managed dotfiles → ~/.config/
dot_local/      Chezmoi-managed → ~/.local/ (Flatpak app overrides, KDE Flexoki color schemes)
dot_var/        Chezmoi-managed → ~/.var/ (VSCodium Flatpak config)
dot_zshrc       → ~/.zshrc
utils/          Scripts (NOT deployed by chezmoi). Some scripts referenced by
                WM configs aren't checked in yet — see Gotcha 1.
```

`flake/` and `utils/` are excluded from chezmoi deployment via `.chezmoiignore`.

---

## NixOS Flake

### Hosts

| Host | Arch | Profile | Role |
|------|------|---------|------|
| `omen15` | x86\_64 | desktop | Primary laptop (AMD + NVIDIA) |
| `oci` | aarch64 | server | Oracle Cloud — self-hosted services |
| `rpi4-side-gateway` | aarch64 | server | Raspberry Pi 4 — transparent proxy gateway |
| `rpi4-switch` | aarch64 | server | Raspberry Pi 4 — router / SQM switch |

> `oci` also runs a host-local `features/agent.nix` ("hermes-agent", a
> Telegram-bot-backed AI agent) that isn't exported via `nixosModules` and thus
> isn't in the module table below — it's only ever imported directly by `oci`.

### Using as a Flake Input

Add this flake as an input and import any `nixosModules.*` you want:

> **Note:** `nixosModules.core` uses `inputs` internally (nix-index-database).
> You must pass `specialArgs = { inherit inputs; }` in your `lib.nixosSystem` call.

```nix
# flake.nix
inputs.hydroakri-nixos.url = "github:hydroakri/dotfiles?dir=flake";

# your host configuration (lib.nixosSystem)
# specialArgs = { inherit inputs; };   ← required when using nixosModules.core
{ inputs, ... }: {
  imports = [
    inputs.hydroakri-nixos.nixosModules.core
    inputs.hydroakri-nixos.nixosModules.security
    inputs.hydroakri-nixos.nixosModules.performance
  ];

  mainUser = "alice";                           # default "user" is not useful — always set this

  modules.core.extraSubstituters = [            # optional extra caches
    "https://nix-community.cachix.org"
  ];
  modules.core.extraTrustedPublicKeys = [
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  modules.security.authorizedKeys = [           # SSH keys for root
    "ssh-ed25519 AAAA... alice@laptop"
  ];
  modules.security.u2fMappings = ''             # leave empty to skip u2f PAM
    alice:<pamu2fcfg output>
  '';
}
```

Only `core`, `security`, and `performance` are shown above because their
`nixosModules` name matches their `modules.*` config namespace 1:1. For every
other module, the import name and the config path differ — check the **Config
path** column in the table below before setting options.

### Available `nixosModules`

| Name | Description | Config path |
|------|-------------|--------------|
| [`core`](flake/modules/core.nix) | Base layer for all hosts: Nix settings & extra binary caches, Unbound DNS, Chrony NTS, terminal tooling, SMART monitoring. Also imports `sqm.nix`/`tuning.nix`, so SQM and NIC-tuning capability come for free on every host (both disabled by default). Side effects worth knowing: hardcodes `networking.nameservers` to Cloudflare (`172.64.36.2`) + Quad9 (`149.112.112.11`), and an SSH client override routes all `github.com` traffic through `ssh.github.com:443`. | always-on; `modules.core.extraSubstituters` / `extraTrustedPublicKeys` |
| [`desktop`](flake/modules/desktop.nix) | Desktop profile: `preempt=full`, PipeWire, XDG portals, Vulkan/OpenGL. Conventionally not combined with `server` — no `assertions` enforce this, it's just host-file discipline. | always-on |
| [`server`](flake/modules/server.nix) | Server profile: `preempt=voluntary`, tuned, fail2ban, irqbalance. Conventionally not combined with `desktop` (same caveat). | always-on |
| [`performance`](flake/modules/features/performance.nix) | BBR+CAKE networking, MGLRU, zram, scx scheduler, I/O scheduler udev rules. | always-on; `modules.performance.vendor` |
| [`security`](flake/modules/features/security.nix) | Kernel hardening, AppArmor, doas, u2f PAM, FIDO2 SSH, USBGuard, sysctl baseline. | always-on; `modules.security.authorizedKeys` / `u2fMappings` |
| [`privacy`](flake/modules/features/privacy.nix) | Anti-tracking/anti-fingerprinting: Brave hardening policy, kloak keystroke/mouse timing anonymization, MAC address randomization, IPv6 privacy addresses. | always-on |
| [`powersave`](flake/modules/features/powersave.nix) | `power-profiles-daemon`, s2idle, dynamic audio power-save udev rules. | gated: `modules.powersave.enable` |
| [`gaming`](flake/modules/features/gaming.nix) | scx_lavd scheduler, Gamescope, GameMode, Steam firewall ports. Importing this does **not** turn Steam on by itself — `programs.steam.enable` still defaults to `false`. | always-on (Steam opt-in separately) |
| [`utils`](flake/modules/features/utils.nix) | Prometheus + node-exporter, Grafana, Uptime Kuma, plus `enableGraphicTools` (GPU diagnostic packages). *Glance is not configured here* — it only exists as a bare nginx reverse-proxy vhost on `oci` pointing at a service that isn't declared anywhere in Nix (run out-of-band). | gated: `modules.utils.enable` |
| [`virtualisation`](flake/modules/features/virtualisation.nix) | Podman + Docker shim, qemu binfmt for aarch64 cross-run. | always-on |
| [`preservation`](flake/modules/features/preservation.nix) | tmpfs-on-root with preservation-based state persistence (NetworkManager state, Unbound/Chrony state, SSH host keys, machine-id, `/var/lib/*` for many services); used by `omen15`. | gated: `modules.preservation.enable` / `persistentPath` |
| [`networking-proxy`](flake/modules/features/networking/proxy.nix) | sing-box FakeIP + dnscrypt-proxy + AdGuardHome + optional dae eBPF. | gated: `modules.proxy.enable` |
| [`networking-router`](flake/modules/features/networking/router.nix) | NAT router: VLAN, DHCP, MSS clamping, disables strict reverse-path filtering (`networking.firewall.checkReversePath = false`). | gated: `modules.router.enable` |
| [`networking-sqm`](flake/modules/features/networking/sqm.nix) | CAKE SQM via `tc` — bufferbloat control on WAN interface. Already pulled in by `core` (disabled by default); most hosts won't import this module directly. | gated: `modules.networking.sqm.enable` |
| [`networking-tuning`](flake/modules/features/networking/tuning.nix) | sysfs NIC tuning: RPS/XPS CPU affinity via udev. Already pulled in by `core`. | gated: `modules.networking.sysfsTuning.enable` |
| [`hardware-amd`](flake/modules/hardware/amd.nix) | AMD GPU: always enables `hardware.amdgpu.overdrive` + `services.lact` (GPU control daemon); ROCm is opt-in. Does **not** configure zenpower — that's hand-built per-host, only on `omen15` (custom kernel module build). | base always-on; ROCm gated by `modules.amd.rocm` |
| [`hardware-nvidia`](flake/modules/hardware/nvidia.nix) | NVIDIA driver (open/proprietary/nouveau via `variant`), prime offload. | gated: `modules.nvidia.enable` |
| [`filesystem-btrfs`](flake/modules/filesystems/btrfs.nix) | Btrfs maintenance: `services.btrfs.autoScrub`, a custom `btrfs-balance` oneshot+timer, `services.snapper` (hourly snapshots on `/` and `/home`). Does **not** set subvolume layout/compression/mount options — those are host-specific, see `flake/hosts/omen15/disko.nix` (its only current consumer). | always-on |

**Gated modules at a glance:** `powersave`, `utils`, `preservation`,
`networking-proxy`, `networking-router`, `networking-sqm`,
`networking-tuning`, `hardware-nvidia`, plus `hardware-amd`'s `rocm`
sub-option. Everything else is always-on when imported.

### Key Options

**`mainUser`** *(string, default: `"user"`)* — system username; used throughout modules for home paths, groups, and PAM.

**`modules.core.extraSubstituters`** *(list)* — binary caches appended after `cache.nixos.org`.

**`modules.core.extraTrustedPublicKeys`** *(list)* — trusted public keys for extra caches.

**`modules.security.authorizedKeys`** *(list, default: `[]`)* — SSH public keys granted root login. Default empty means root SSH is disabled; always set this on any host you need to reach.

**`modules.security.u2fMappings`** *(multiline string)* — contents of `/etc/u2f_mappings` from `pamu2fcfg -n`; empty string disables u2f PAM entirely.

**`modules.performance.vendor`** *(enum: `amd` | `intel` | `other`, default: `"other"`)* — selects microcode update package. Default `"other"` skips microcode entirely; always set this explicitly to `amd` or `intel` when the CPU vendor is known, since there's no autodetection.

### Common Commands

(These commands build/manage this repo's own hosts. Consuming this flake as a
dependency from another repo instead? See "Using as a Flake Input" above.)

```bash
# Build and switch (from repo root)
nh os switch -H omen15 ./flake
nh os switch -H oci ./flake
nh os switch -H rpi4-side-gateway ./flake

# Test build without activating
nixos-rebuild build --flake ./flake#omen15

# Update flake inputs
nix flake update --flake ./flake

# Build images
nix build ./flake#packages.x86_64-linux.iso-installer
nix build ./flake#packages.aarch64-linux.rpi-image

# Init ROS2 dev shell elsewhere
nix flake init -t 'github:hydroakri/dotfiles?dir=flake#ros2'
```

### CI / Build Pipeline

Two GitHub Actions workflows build and maintain this flake:

- **`build.yml`** ("Build and Push to Attic Cache") — on push to `main` or
  manual dispatch, matrix-builds all four
  `nixosConfigurations.*.config.system.build.toplevel` (`omen15` on
  x86_64-linux/ubuntu-latest; `oci`, `rpi4-side-gateway`, `rpi4-switch` on
  aarch64-linux/ubuntu-24.04-arm) and pushes to the self-hosted Attic cache at
  `cache.hydroakri.cc`, plus a secondary "LanTian" substituter. The x86_64 job
  runs a disk-cleanup step first.
- **`flake-update.yml`** — on PRs, sanity-checks `nix flake show ./flake`. On
  a daily cron (and manual dispatch), checks NixOS Hydra channel health and
  kernel hash drift, opening an auto-merged PR that bumps `flake.lock` via
  `DeterminateSystems/update-flake-lock` when warranted.

> Add `cache.hydroakri.cc` to `modules.core.extraSubstituters` if you're
> consuming this flake as an input — CI keeps it populated with prebuilt hosts.

### Secrets (sops-nix)

```bash
# Edit encrypted secrets (run from flake/modules/features/secrets/)
sops secrets.yaml

# Re-encrypt after changing recipients in .sops.yaml
sops updatekeys secrets.yaml
```

Secrets are age-encrypted. Recipients are defined in `.sops.yaml` and tied to
each host's SSH ed25519 host key. **Back up `/etc/ssh` before any reinstall** —
loss of the host key makes secrets permanently undecryptable.

---

## Dotfiles (Chezmoi)

Managed via chezmoi naming conventions: `dot_config/` → `~/.config/`, `executable_` → `+x`.

```bash
chezmoi diff          # preview changes
chezmoi apply         # deploy to $HOME
chezmoi apply ~/.config/niri  # apply single target
chezmoi update        # pull + apply
```

### Desktop Stack

- **Compositors**: Hyprland, Niri, Sway (Wayland)
- **Terminal / Shell**: Zsh via **antidote** (plugin manager — bootstrapped
  with a blocking `git clone --depth=1` on first run, then `antidote load`
  reads `dot_zsh_plugins.txt`: zsh-completions, fzf-tab, zsh-sage), plus
  **zsh-patina** (syntax highlighting, fetched separately via `curl`+`tar`
  from a GitHub release tarball); WezTerm, Ghostty
- **Theming**: Flexoki + Adw-gtk3 + qt6ct, centralized via `utils/chtheme.sh`.
  Pywal support and zellij/wezterm/alacritty color injection exist in the
  script but are currently commented out/inactive. qt6ct only — qt5ct color
  files exist under `dot_config/qt5ct/colors/` but chtheme.sh doesn't touch them.
- **Input**: Fcitx5 + rime-wanxiang, provisioned as Nix packages by the
  `desktop` flake module (`pkgs.fcitx5-rime`, `pkgs.rime-wanxiang`,
  `pkgs.fcitx5-gtk`, ...) — not via chezmoi
- **External plugin managers**: `.chezmoiexternal.toml`'s only entry pulls
  tmux's TPM into `~/.tmux/plugins/tpm`; zsh plugins go through antidote (above)

### Gotchas

1. **`~/utils/` is not deployed by chezmoi** — WM configs hardcode `~/utils/`
   paths (Hyprland execs `~/utils/bemenu`, `~/utils/rofi.sh`,
   `~/utils/gamemode.sh`, `~/utils/chgwllpr.sh`). **Known gap:** none of those
   four scripts are actually checked into `utils/` yet — it currently only
   contains `chtheme.sh`, `screen-locker.sh`, and a `backup/` folder of static
   extension-settings snapshots. You'll need to write them yourself before
   those keybinds/execs work.

2. **`utils/chtheme.sh` mutates configs in place** — rewrites
   `~/.config/qt6ct/qt6ct.conf` (qt5ct is untouched), GTK CSS, and mako
   config, then reloads mako/gsettings/plasma colorscheme. Pywal invocation
   and terminal color injection exist in the script but are commented out.
   Disable/edit it if you don't use Flexoki + Adw-gtk3 + qt6ct.

3. **Wallpapers are hardcoded** — compositors expect `~/Pictures/wllppr/wall.jpg`. Populate or edit the path.

4. **Zsh plugin bootstrap is synchronous, not backgrounded** — `.zshrc` uses
   antidote as its plugin manager; on first run it does a blocking
   `git clone --depth=1` to install antidote, then loads
   `dot_zsh_plugins.txt` (zsh-completions, fzf-tab, zsh-sage). Separately,
   `.zshrc` also synchronously fetches `zsh-patina` via `curl`+`tar` from a
   GitHub release into `~/.zsh/zsh-patina`. Expect a startup pause on a fresh
   machine or after clearing `~/.zsh/`.

---

## License

[MIT](LICENSE) — feel free to fork and adapt.
