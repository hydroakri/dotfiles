# hydroakri's NixOS & Dotfiles

> Multi-host NixOS flake + Chezmoi dotfiles for Wayland desktops and ARM servers.

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
dot_zshrc       → ~/.zshrc
utils/          Scripts (NOT deployed by chezmoi — provision manually)
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

### Available `nixosModules`

| Name | Description |
|------|-------------|
| [`core`](flake/modules/core.nix) | Base layer: Nix settings, caches, Unbound DNS, Chrony NTS, terminal tooling, SMART. Also declares `networking-sqm` and `networking-tuning` options. **Side effects:** sets `time.timeZone = "UTC"` and opens UDP 7400–7500 inbound (ROS2/DDS multicast hardcoded) |
| [`desktop`](flake/modules/desktop.nix) | Desktop profile: `preempt=full`, PipeWire, XDG portals, Vulkan/OpenGL. **Mutually exclusive with `server`** |
| [`server`](flake/modules/server.nix) | Server profile: `preempt=voluntary`, tuned, fail2ban, irqbalance. **Mutually exclusive with `desktop`** |
| [`performance`](flake/modules/features/performance.nix) | BBR+CAKE networking, MGLRU, zram, scx scheduler, I/O scheduler udev rules |
| [`security`](flake/modules/features/security.nix) | Kernel hardening, AppArmor, doas, u2f PAM, FIDO2 SSH, sysctl baseline |
| [`powersave`](flake/modules/features/powersave.nix) | TLP/power-profiles-daemon, s2idle, dynamic audio power-save udev rules |
| [`gaming`](flake/modules/features/gaming.nix) | scx_lavd scheduler, Gamescope, GameMode, Steam firewall ports |
| [`utils`](flake/modules/features/utils.nix) | Glance dashboard, Prometheus+Grafana stack, Uptime Kuma |
| [`virtualisation`](flake/modules/features/virtualisation.nix) | Podman + Docker shim, qemu binfmt for aarch64 cross-run |
| [`networking-proxy`](flake/modules/features/networking/proxy.nix) | sing-box FakeIP + dnscrypt-proxy + AdGuardHome + optional dae eBPF |
| [`networking-router`](flake/modules/features/networking/router.nix) | NAT router: VLAN, DHCP, MSS clamping, rp_filter relaxation |
| [`networking-sqm`](flake/modules/features/networking/sqm.nix) | CAKE SQM via `tc` — bufferbloat control on WAN interface |
| [`networking-tuning`](flake/modules/features/networking/tuning.nix) | sysfs NIC tuning: RPS/XPS CPU affinity via udev |
| [`hardware-amd`](flake/modules/hardware/amd.nix) | AMD GPU (AMDGPU), zenpower, ROCm |
| [`hardware-nvidia`](flake/modules/hardware/nvidia.nix) | NVIDIA driver (open or proprietary), prime offload |
| [`filesystem-btrfs`](flake/modules/filesystems/btrfs.nix) | Btrfs subvolume layout with zstd compression and noatime |

**Module activation:**

- **Always-on when imported** (no `enable` flag): `core`, `desktop`, `server`, `performance`, `security`, `gaming`, `virtualisation`, `filesystem-btrfs`, `hardware-amd`
- **Gated by `modules.<name>.enable = true`**: `powersave`, `utils`, `hardware-nvidia`, `networking-proxy`, `networking-sqm`, `networking-tuning`

### Key Options

**`mainUser`** *(string, default: `"user"`)* — system username; used throughout modules for home paths, groups, and PAM.

**`modules.core.extraSubstituters`** *(list)* — binary caches appended after `cache.nixos.org`.

**`modules.core.extraTrustedPublicKeys`** *(list)* — trusted public keys for extra caches.

**`modules.security.authorizedKeys`** *(list, default: `[]`)* — SSH public keys granted root login. Default empty means root SSH is disabled; always set this on any host you need to reach.

**`modules.security.u2fMappings`** *(multiline string)* — contents of `/etc/u2f_mappings` from `pamu2fcfg -n`; empty string disables u2f PAM entirely.

**`modules.performance.vendor`** *(enum: `amd` | `intel` | `other`, default: `"other"`)* — selects microcode update package. Default `"other"` skips microcode entirely; always set this explicitly.

### Common Commands

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
- **Terminal / Shell**: Zsh (async plugin fetch), WezTerm, Ghostty, Foot
- **Theming**: Pywal + Flexoki + Adw-gtk3, Qt5ct/Qt6ct, centralized via `utils/chtheme.sh`
- **Input**: Fcitx5 (rime-ice dictionary via `.chezmoiexternal.toml`)

### Gotchas

1. **`~/utils/` is not deployed** — WM configs hardcode `~/utils/` paths. Provision scripts there manually. `.zshrc` adds `~/script` (different dir) to `$PATH`.

2. **`utils/chtheme.sh` mutates configs** — rewrites `~/.config/qt6ct/qt6ct.conf`, GTK CSS, and mako config in-place. Disable it if you don't use Pywal + Flexoki + Adw-gtk3.

3. **Wallpapers are hardcoded** — compositors expect `~/Pictures/wllppr/wall.jpg`. Populate or edit the path.

4. **Zsh plugins are async-fetched** — no plugin manager; `.zshrc` spawns a background `git clone/pull` into `~/.zsh/` on first run.

---

## License

[CC0](https://creativecommons.org/publicdomain/zero/1.0/) — fork freely.
