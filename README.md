# hydroakri's NixOS & Dotfiles

[![CI](https://github.com/hydroakri/dotfiles/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/ci.yml)
[![Update Flake Lock](https://github.com/hydroakri/dotfiles/actions/workflows/update-flake-lock.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/update-flake-lock.yml)
[![Update Home Manager Lock](https://github.com/hydroakri/dotfiles/actions/workflows/update-home-manager-lock.yml/badge.svg?branch=main)](https://github.com/hydroakri/dotfiles/actions/workflows/update-home-manager-lock.yml)

> Multi-host NixOS flake + a portable home-manager flake + chezmoi dotfiles.

*[中文](README_ZH.md)*

## Contents

- [⚠️ This is my personal configuration](#personal-config)
- [Defaults Worth Knowing About](#defaults-worth-knowing-about)
- [How do I...](#how-do-i)
  - [...reuse a single module in my own flake?](#reuse-a-single-module-in-my-own-flake)
  - [...add or switch a host?](#add-or-switch-a-host)
  - [...edit or rotate secrets?](#edit-or-rotate-secrets)
  - [...enable a module that's off by default?](#enable-a-module-thats-off-by-default)
  - [...bootstrap CLI tooling with home-manager?](#bootstrap-cli-tooling-with-home-manager)
  - [...apply or update my dotfiles?](#apply-or-update-my-dotfiles)
  - [...fix the known dotfiles gotchas?](#fix-the-known-dotfiles-gotchas)
- [Reference](#reference)
  - [Repository Structure](#repository-structure)
  - [Hosts](#hosts)
  - [Available `nixosModules`](#available-nixosmodules)
  - [Key Options](#key-options)
  - [Common Commands](#common-commands)
  - [CI / Build Pipeline](#ci-build-pipeline)
  - [Home Manager](#home-manager)
  - [Desktop Stack](#desktop-stack)
  - [Reference Sources](#reference-sources)
- [License](#license)

<a id="personal-config"></a>

## ⚠️ This is my personal configuration — read before reusing

Hostnames, `hydroakri.cc` domains, real SSH/FIDO2 keys, and sops-encrypted
secrets live in `flake/hosts/*`, `flake/hosts/personal-proxy-profile.nix`, and
`flake/modules/features/secrets/`. **None of those files are exported as
`nixosModules`**, so importing any module from the [Reference](#reference)
section below never pulls in my secrets — the modules themselves are
extension points, not identity.

What you *do* need to supply yourself: `mainUser`,
`modules.security.authorizedKeys`, `modules.security.u2fMappings`, and (if you
want your own binary cache) `modules.core.extraSubstituters`. These default to
empty/non-functional values on purpose.

A few modules also bake in *infrastructure* defaults that aren't secret but
are still my preference, not a universal default — e.g. `core.nix`'s DNS
resolvers (Cloudflare + Quad9) and its `Host github.com` SSH-over-443
override. Read a module before assuming its defaults suit you. See
[Defaults Worth Knowing About](#defaults-worth-knowing-about) for the full list.

---

## Defaults Worth Knowing About

None of these are secrets — they're infrastructure/package choices baked
into shared modules that a reuser (or future me) could easily miss:

| Default | Where | Why it might surprise you |
|---|---|---|
| **Lix, not upstream Nix** | `core.nix`: `nix.package = pkgs.lix;` (also set independently in the standalone home-manager flake) | The Lix fork, not `nixpkgs`' own Nix, runs the daemon on every host this repo manages. |
| **Rust coreutils, not GNU** | `core.nix`: `lib.hiPrio pkgs.uutils-coreutils-noprefix` | `uutils` shadows GNU coreutils in `PATH`. Mostly compatible, but not a byte-for-byte match — scripts relying on GNU-specific flag behavior can hit edge cases. |
| **doas, not sudo** | `security.nix`: `security.sudo.enable`/`sudo-rs.enable` both `false`, `security.doas.enable = true` | `pkgs.doas-sudo-shim` makes `sudo` resolve to `doas` for muscle memory, but doas doesn't support every sudo flag — scripts hardcoding sudo-specific options can break. |
| **Hardened malloc by default** | `security.nix`: `environment.memoryAllocator.provider = "graphene-hardened-light"` | Trades some performance for hardening. The module comment notes the alternatives: `scudo` (balanced), `mimalloc` (performance). |
| **musl + LibreSSL + clang builds for several daemons** | `core.nix`: unbound, chrony, openssh, wget; `proxy.nix`: dnscrypt-proxy, sing-box (all via `pkgsMusl`/`libressl`/`clangStdenv` overrides) | Smaller attack surface, static binaries — but these are off the standard binary cache, so the first build on a machine compiles from source. (`oci.nix` overlays its own nginx the same way, but that's a host-level overlay, not a shared module.) |
| **Unbound runs, but isn't necessarily your resolver** | `core.nix` enables `services.unbound` on `127.0.0.1`, but `networking.nameservers` defaults to Cloudflare+Quad9 *directly* — no host overrides this | Nothing points system DNS at unbound by default. That only happens when `modules.proxy` is enabled (`networking.networkmanager.insertNameservers = [ "127.0.0.1" ]`, gated behind `adguardhome`/`dnscrypt-proxy`/`singbox.dns`). Without proxy enabled, unbound is running but idle from the OS's point of view. |
| **iwd for WiFi — except on my own laptop** | `desktop.nix`: `networking.networkmanager.wifi.backend = "iwd"` (`mkOverride 900`) — but `omen15.nix` sets it back to `"wpa_supplicant"` with a plain assignment, which wins | Even the reference host doesn't use the shipped default (driver-specific compatibility reasons, not stated in-repo). Don't assume iwd works for your WiFi chipset just because it's the module default. |
| **Geoclue (location service) on by default** | `desktop.nix`: `services.geoclue2.enable = true` (`mkOverride 900`) | Cuts against the rest of `privacy.nix`'s anti-fingerprinting work — apps can request your location unless you disable this yourself. |
| **No local printer/mDNS/mobile-broadband discovery on desktop** | `desktop.nix`: `services.printing.enable`, `services.avahi.enable`, `networking.modemmanager.enable` all `false` (`mkOverride 900`) | No CUPS printer autodiscovery or mDNS `.local` resolution out of the box. |
| **earlyoom, not systemd-oomd** | `performance.nix`: `systemd.oomd.enable = false`, `services.earlyoom.enable = true` (with an `--avoid` regex protecting game/Wine/Proton processes) | If a process gets OOM-killed unexpectedly, check `earlyoom`'s thresholds/avoid-list, not `oomd`'s. |
| **chrony is enabled; systemd-timesyncd is never explicitly turned off** | `core.nix` enables `services.chrony` (NTS-secured servers); nothing sets `services.timesyncd.enable = false` | nixpkgs' own `services.chrony.enable` description literally says "make sure you disable NTP if you enable this service" — worth checking `systemctl status systemd-timesyncd.service` on a real host rather than assuming chrony is the only thing adjusting the clock. |
| **`services.resolved.enable = false` in `router.nix` is defensive, not a real override** | `router.nix` sets it under `mkDefault` when its DHCP server is on | NixOS ships with `services.resolved` disabled by default anyway — this line guards against it being turned on elsewhere, it isn't undoing anything active. |

---

## How do I...

### ...reuse a single module in my own flake?

Add this flake as an input, import whichever `nixosModules.*` you want (full
list in [Reference](#available-nixosmodules)), and supply the options it
needs. Most modules need nothing extra — this imports exactly one:

```nix
# your flake.nix
inputs.hydroakri-nixos.url = "github:hydroakri/dotfiles?dir=flake";

# your host module
{ inputs, ... }: {
  imports = [ inputs.hydroakri-nixos.nixosModules.security ];

  mainUser = "alice";                          # default "user" is non-functional — always set this
  modules.security.authorizedKeys = [
    "ssh-ed25519 AAAA... alice@laptop"
  ];
}
```

> `nixosModules.core` is the one exception that needs `specialArgs = { inherit
> inputs; };` in your `lib.nixosSystem` call, because it wires in
> `nix-index-database`. Modules without an `inputs` argument (most of them)
> don't need this.

To pull in several at once:

```nix
imports = [
  inputs.hydroakri-nixos.nixosModules.core        # needs specialArgs, see above
  inputs.hydroakri-nixos.nixosModules.security
  inputs.hydroakri-nixos.nixosModules.performance
];
modules.core.extraSubstituters = [ "https://nix-community.cachix.org" ];
modules.performance.vendor = "amd";               # default "other" skips microcode entirely
```

### ...add or switch a host?

To switch one of this repo's own four hosts (from the repo root):

```bash
nh os switch -H omen15 ./flake
nh os switch -H oci ./flake
nh os switch -H rpi4-side-gateway ./flake
nh os switch -H rpi4-switch ./flake

# test-build without activating
nixos-rebuild build --flake ./flake#omen15
```

To add a new host: create `flake/hosts/<name>/<name>.nix`, import exactly one
of `desktop.nix`/`server.nix` (never both — see the profile note in
[Reference](#available-nixosmodules)), then add it to `nixosConfigurations`
in `flake/flake.nix`. Nothing else needs updating — the CI build matrix is
generated at run time from `nix eval .#githubActions.matrix`, so a new host
gets picked up automatically.

### ...edit or rotate secrets?

```bash
# run from flake/modules/features/secrets/
sops secrets.yaml            # all-hosts secrets
sops proxy-secrets.yaml      # scoped to hydroakri + omen15 + rpi4 only (not oci)

# after changing recipients in .sops.yaml
sops updatekeys secrets.yaml
```

Recipients are tied to each host's SSH ed25519 host key — **back up
`/etc/ssh` before any reinstall**, or those secrets become permanently
undecryptable.

### ...enable a module that's off by default?

Check the **Config path** column in [Reference](#available-nixosmodules) —
most feature modules are `always-on` once imported, but a subset need an
explicit `enable`:

```nix
modules.powersave.enable = true;
modules.preservation.enable = true;              # + persistentPath if you don't want /persistent
modules.utils.enable = true;                      # + enableGrafana/enablePrometheus/enableUptime individually
modules.virtualisation.libvirtd.enable = true;    # KVM/QEMU + virt-manager
modules.proxy.enable = true;                       # + singbox.enable / dae.enable / dnscrypt-proxy.enable individually
modules.router.enable = true;                       # + lan.interfaces, at minimum
modules.networking.sqm.enable = true;
modules.networking.sysfsTuning.enable = true;
modules.nvidia.enable = true;                        # + variant, amdgpuBusId/nvidiaBusId for hybrid laptops
modules.amd.rocm = true;
```

### ...bootstrap CLI tooling with home-manager?

Works on **any** Linux with just Nix installed — not only my NixOS hosts
(what's actually inside is in [Reference](#home-manager)):

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
nix shell nixpkgs#git nixpkgs#chezmoi -c chezmoi init --apply https://github.com/hydroakri/dotfiles
nix run home-manager/master -- switch --flake ~/.config/home-manager#$USER --impure
nh home switch -- --impure   # subsequent switches (note the trailing --, not a leading flag)
```

⚠️ Its `flake.nix` pins `nixpkgs` via `nixos-flake.url =
"github:hydroakri/dotfiles?dir=flake"` — i.e. it follows *this* repo's
nixpkgs, not its own pin. If you fork just this piece without the NixOS
flake, repoint that input.

### ...apply or update my dotfiles?

```bash
chezmoi diff                  # preview changes
chezmoi apply                 # deploy to $HOME
chezmoi apply ~/.config/niri  # apply a single target
chezmoi update                 # pull + apply
```

Naming conventions: `dot_config/` → `~/.config/`, `executable_` → `+x`,
`modify_` → a script that transforms the existing target file (e.g.
`modify_dot_gitconfig`, which merges a commit-signing block into
`~/.gitconfig` on every apply without touching the rest of the file). Stack
details are in [Reference](#desktop-stack).

### ...fix the known dotfiles gotchas?

1. **Hyprland keybinds don't work.** `dot_config/hypr/hyprland.conf` execs
   `~/utils/bemenu`, `~/utils/rofi.sh`, `~/utils/gamemode.sh` — none of these
   are checked into `utils/` (chezmoi-ignored, currently just a `backup/`
   folder of static extension-setting exports). Write them yourself, or stay
   on Niri, which has no such references — `flake/modules/desktop.nix` only
   enables Niri at the NixOS level anyway.

2. **Wallpaper doesn't show up on a new machine.** Two unrelated hardcoded
   paths need editing: `dot_config/noctalia/settings.json` →
   `"directory": "/home/hydroakri/Pictures/Wallpapers"` (Niri, via noctalia's
   rotation), and `dot_config/hypr/hyprland.conf`'s live `exec-once = swaybg
   -i ~/Pictures/wllppr/wall.jpg -m fill` (Hyprland, unrelated to noctalia).

3. **Shell startup is slow on a fresh machine or after clearing `~/.zsh/`.**
   Two blocking network fetches happen on first run: antidote's
   `git clone --depth=1`, and zsh-patina's `curl`+`tar` release fetch. Nothing
   to fix — pre-seed `~/.antidote` and `~/.zsh/zsh-patina` yourself if you
   want to skip the pause.

4. **Git commits aren't signed / signature shows as unverified.**
   `modify_dot_gitconfig` sets `commit.gpgsign = true` + `gpg.format = ssh`
   for you, but the key still needs to exist in your GitHub account *and* in
   the target host's sops `allowed_signers` template — currently only wired
   up for `omen15`.

---

## Reference

### Repository Structure

```
flake/                  NixOS flake (multi-host, declarative)
├── hosts/               Per-machine entry points + personal-proxy-profile.nix
├── modules/              Shared modules imported by hosts
│   ├── core.nix            Base layer for all hosts
│   ├── desktop.nix         Desktop profile (latency-tuned)
│   ├── server.nix          Server profile (throughput-tuned)
│   └── features/            Opt-in capabilities
└── templates/            Dev-shell templates (ros2)

dot_config/home-manager/  Standalone home-manager flake (portable CLI tooling)

dot_config/               Everything else here is chezmoi-managed → ~/.config/
dot_local/                 → ~/.local/ (Flatpak overrides, KDE Flexoki colors)
dot_var/                   → ~/.var/ (VSCodium Flatpak config)
dot_zshrc                  → ~/.zshrc
modify_dot_gitconfig        → ~/.gitconfig (injects commit signing block)
utils/                    Scripts (NOT deployed by chezmoi, currently just a
                           backup/ folder of static extension-setting exports)
```

`flake/` and `utils/` are excluded from chezmoi deployment via
`.chezmoiignore` (which also excludes all `*.md` files, so this doc never
gets copied into `$HOME`).

### Hosts

| Host | Arch | Profile | Role |
|------|------|---------|------|
| `omen15` | x86_64 | desktop | Primary laptop (AMD + NVIDIA hybrid, pinned CachyOS kernel) |
| `oci` | aarch64 | server | Oracle Cloud — vaultwarden, searx, atticd, headscale, a Minecraft server, nginx reverse-proxying several `*.hydroakri.cc` vhosts |
| `rpi4-side-gateway` | aarch64 | server | Raspberry Pi 4 — transparent proxy (sing-box + dnscrypt-proxy + dae), no DHCP/NAT |
| `rpi4-switch` | aarch64 | server | Raspberry Pi 4 — LAN router: DHCP, NAT, SQM; no proxy stack |

Two more flake packages build standalone images rather than a host config:
`packages.x86_64-linux.iso-installer` (graphical Calamares installer ISO) and
`packages.aarch64-linux.rpi-image` (bootstrap SD image — its wifi PSK and
root password are literal placeholders, edit `flake/hosts/rpi-image/` before
flashing).

Two profile modules are mutually exclusive — pick exactly one per host, no
`assertions` enforce this, it's host-file discipline only:
[`desktop`](flake/modules/desktop.nix) (`preempt=full`) or
[`server`](flake/modules/server.nix) (`preempt=voluntary`).

### Available `nixosModules`

| Name | Description | Config path | Reuse notes |
|------|-------------|--------------|-------------|
| [`core`](flake/modules/core.nix) | Nix settings/extra caches, Unbound DNS, Chrony NTS, terminal tooling, SMART monitoring. Also pulls in `sqm.nix`/`tuning.nix` (disabled by default). | always-on; `modules.core.extraSubstituters`/`extraTrustedPublicKeys` | Needs `specialArgs={inherit inputs;}`. Ships hardcoded DNS (Cloudflare+Quad9) + GitHub-over-443 SSH routing as plain defaults, not options. |
| [`desktop`](flake/modules/desktop.nix) | `preempt=full`, PipeWire, XDG portals, `hardware.graphics` (Vulkan/OpenGL/OpenCL), fcitx5, nixpak-sandboxed Brave/Mullvad Browser. Only Niri is actually wired to a `programs.*.enable` here. | always-on | — |
| [`server`](flake/modules/server.nix) | `preempt=voluntary`, tuned, fail2ban, irqbalance, bufferbloat sysctls. | always-on | — |
| [`performance`](flake/modules/features/performance.nix) | BBR+CAKE, MGLRU/zram, scx scheduler, I/O-scheduler udev rules, vendor microcode. | always-on; `modules.performance.vendor` | Default `"other"` skips microcode — set explicitly. |
| [`security`](flake/modules/features/security.nix) | Kernel hardening, AppArmor, doas, FIDO2 SSH/PAM, USBGuard, sysctl baseline (with a stricter sub-block on headless hosts). | always-on; `modules.security.authorizedKeys`/`u2fMappings` | ⚠️ Both default empty — root SSH login and u2f PAM are effectively off until you set them. |
| [`privacy`](flake/modules/features/privacy.nix) | Anti-fingerprinting: Brave hardening policy, kloak keystroke/mouse timing anonymization, MAC/IPv6 privacy addressing, Unbound RPZ blocklist + DoT forwarders. | always-on | Forwarders are public resolvers (Quad9/Cloudflare/AdGuard/Mullvad/Control D), not personal endpoints. |
| [`powersave`](flake/modules/features/powersave.nix) | Battery-optimized kernel params, aggressive PCIe ASPM, per-AC/battery udev rules for s2idle efficiency. | gated: `modules.powersave.enable` | — |
| [`gaming`](flake/modules/features/gaming.nix) | scx_lavd scheduler, Gamescope, GameMode, Steam firewall ports. Importing this doesn't turn Steam on — `programs.steam.enable` still defaults to `false`. | always-on (Steam opt-in) | — |
| [`preservation`](flake/modules/features/preservation.nix) | tmpfs-on-root with preservation-based state persistence (NetworkManager, Unbound/Chrony state, SSH host keys, machine-id, most `/var/lib/*`). | gated: `modules.preservation.enable`/`persistentPath` | Adding to a host with existing data needs a manual `rsync` first — preservation won't migrate it for you. |
| [`utils`](flake/modules/features/utils.nix) | Prometheus + node-exporter, Grafana, Uptime Kuma, plus `enableGraphicTools` (GPU diagnostic packages: nvtop, vulkan-tools, clinfo, ...). | gated: `modules.utils.enable` + `enableGrafana`/`enablePrometheus`/`enableUptime`/`enableGraphicTools` | Grafana needs a `grafana_secret_key` sops secret — bring your own. *Glance is not configured here* — `oci`'s `glance.hydroakri.cc` vhost is a bare nginx reverse proxy to a service that isn't declared anywhere in Nix (run out-of-band). |
| [`virtualisation`](flake/modules/features/virtualisation.nix) | Podman + Docker shim, aarch64 binfmt emulation (both always-on). | KVM/QEMU+libvirtd gated: `modules.virtualisation.libvirtd.enable` | — |
| [`networking-proxy`](flake/modules/features/networking/proxy.nix) | sing-box (FakeIP/TUN) + dnscrypt-proxy + AdGuardHome + dae eBPF transparent proxy. | gated: `modules.proxy.enable` (+ many sub-toggles) | Genuinely designed for reuse — every secret/endpoint is an extension point (`extraEndpoints`, `outboundsFile`, sing-box's native `_secret` marker, ...); ships **no** personal resolver or endpoint data itself. My own identity is supplied separately via `flake/hosts/personal-proxy-profile.nix`, which is not exported. |
| [`networking-router`](flake/modules/features/networking/router.nix) | NAT router: VLAN, DHCP (dnsmasq), MSS clamping, relaxes reverse-path filtering. | gated: `modules.router.enable` | — |
| [`networking-sqm`](flake/modules/features/networking/sqm.nix) | CAKE SQM via `tc`, applied through a NetworkManager dispatcher script. | gated: `modules.networking.sqm.enable` | Already pulled in by `core` (disabled by default) — most hosts won't import it directly. |
| [`networking-tuning`](flake/modules/features/networking/tuning.nix) | sysfs NIC tuning: RPS/XPS CPU affinity. | gated: `modules.networking.sysfsTuning.enable` | Already pulled in by `core`. |
| [`hardware-amd`](flake/modules/hardware/amd.nix) | AMD GPU: always enables `hardware.amdgpu.overdrive` + `services.lact`; ROCm opt-in. | ROCm gated: `modules.amd.rocm` | Doesn't configure zenpower — that's hand-built per-host (see `omen15.nix`'s `boot.extraModulePackages`). |
| [`hardware-nvidia`](flake/modules/hardware/nvidia.nix) | NVIDIA driver (open/proprietary/nouveau via `variant`), PRIME offload for hybrid AMD+NVIDIA laptops. | gated: `modules.nvidia.enable`/`variant` | Bus IDs default to my laptop's (`PCI:7@0:0:0` / `PCI:1@0:0:0`) — override for your hardware. |
| [`filesystem-btrfs`](flake/modules/filesystems/btrfs.nix) | `services.btrfs.autoScrub`, a monthly balance timer, hourly Snapper snapshots on `/` and `/home`. | always-on | Doesn't set subvolume layout/mount options — see `flake/hosts/omen15/disko.nix`, its only current consumer. |

Modules not in this table exist but are intentionally not exported:
`flake/modules/features/agent.nix` (Hermes Agent / llama.cpp — has a hardcoded
personal Telegram user ID and is only ever imported directly by `omen15`) and
`flake/modules/features/secrets/secrets.nix` (binds sops to my hosts' SSH
host keys).

### Key Options

**`mainUser`** *(string, default `"user"`)* ⚠️ — system username, used
throughout modules for home paths, groups, PAM. The default is deliberately
non-functional.

**`modules.core.extraSubstituters`/`extraTrustedPublicKeys`** *(lists,
default `[]`)* — binary caches appended after `cache.nixos.org` +
`nix-community.cachix.org`. My hosts add `cache.hydroakri.cc` here; you'd add
your own.

**`modules.security.authorizedKeys`** *(list, default `[]`)* ⚠️ — SSH public
keys granted root login. Empty means root SSH is disabled.

**`modules.security.u2fMappings`** *(multiline string, default `""`)* ⚠️ —
contents of `/etc/u2f_mappings` from `pamu2fcfg -n`. Empty disables u2f PAM
entirely.

**`modules.performance.vendor`** *(enum `amd`\|`intel`\|`other`, default
`"other"`)* — selects the microcode package. `"other"` skips microcode.

### Common Commands

```bash
nix flake check ./flake        # evaluate all four hosts, no build (cheap sanity check)
nix fmt ./flake                 # nixfmt + statix + deadnix (config inlined via treefmt-nix)
nix flake update --flake ./flake

nix build ./flake#packages.x86_64-linux.iso-installer
nix build ./flake#packages.aarch64-linux.rpi-image

nix flake init -t 'github:hydroakri/dotfiles?dir=flake#ros2'   # ROS2 dev shell elsewhere
```

<a id="ci-build-pipeline"></a>

### CI / Build Pipeline

| Job / workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` → `check` | push/PR to `flake/**` or `dot_config/home-manager/**`, nightly, manual | `nix flake check` |
| `ci.yml` → `nix-matrix` | same | generates the build matrix from `nix eval .#githubActions.matrix` (`nix-github-actions`) — no manual workflow edit needed to add/remove a host |
| `ci.yml` → `build` | same | matrix-builds all four `nixosConfigurations.*.toplevel` on x86_64/aarch64 runners, pushes to `cache.hydroakri.cc` (self-hosted Attic) + a secondary "LanTian" cache; x86_64 runner frees disk + adds 8G swap first for from-source clang builds |
| `ci.yml` → `home-manager-build` | same | builds the standalone home-manager flake's activation package, unrelated to the four-host matrix |
| `update-flake-lock.yml` | daily cron, manual | bumps `flake/flake.lock` only if the kernel hash changed *and* the NixOS Hydra channel is healthy; auto-merges |
| `update-home-manager-lock.yml` | daily cron, offset 2h after the above | bumps `dot_config/home-manager/flake.lock` (which follows `flake/`'s nixpkgs rather than pinning its own); auto-merges |

> Add `cache.hydroakri.cc` to `modules.core.extraSubstituters` if you're
> consuming this flake as an input — CI keeps it populated.

### Home Manager

`dot_config/home-manager/` is its own flake — CLI tooling only (zsh, neovim,
tmux, zellij, fzf, bat, atuin, zoxide, lazygit, ripgrep, starship, ...), using
bare `home.packages` rather than `programs.zsh`/`git`/`neovim` so it doesn't
fight chezmoi for `~/.zshrc`, `~/.config/git`, `~/.config/nvim`.

### Desktop Stack

- **Compositors**: config directories exist for Hyprland, Niri, and Sway —
  but `flake/modules/desktop.nix` only sets `programs.niri.enable`; Hyprland
  and Sway aren't wired to a NixOS-level enable option here.
- **Shell**: zsh is the declared login shell (`core.nix` sets it for both
  root and `mainUser`), bootstrapped via **antidote** plus **zsh-patina** for
  syntax highlighting. A lighter **fish** config also exists but isn't set as
  anyone's login shell.
- **Terminal**: WezTerm, Ghostty.
- **Theming**: light/dark switching is fully driven by `darkman` via
  `gsettings` — no theme is hardcoded in Nix. `desktop.nix` provisions
  `adw-gtk3`/`qt6ct`/`qt5ct`/`darkman`/`darkly` as system packages; Niri's
  shell/bar is **noctalia-shell**, which also owns wallpaper rotation.
- **Input**: Fcitx5 + rime-wanxiang, provisioned as Nix packages by
  `desktop.nix` (not via chezmoi).
- **External plugin managers**: `.chezmoiexternal.toml` pulls tmux's TPM into
  `~/.tmux/plugins/tpm`; zsh plugins go through antidote.

### Reference Sources

The kernel/sysctl/udev hardening in `security.nix`, `privacy.nix`,
`performance.nix`, `powersave.nix`, `gaming.nix` and `networking/*.nix` is
**adapted, not copied**, from these upstream distributions. Every value is
experimented with per-host before being merged in — nothing in the modules
below is a verbatim drop-in of an upstream file. Per-setting provenance and
the quarterly review process live in
[`docs/upstream-settings.md`](docs/upstream-settings.md). Settings that broke
something on real hardware are tracked in
[`docs/known-breaking-settings.md`](docs/known-breaking-settings.md).

| Distro | Repository | What I take from it |
|---|---|---|
| CachyOS | https://github.com/CachyOS/CachyOS-Settings | sysctl (`70-cachyos-settings.conf`), udev rules, modprobe defaults |
| CachyOS (kernel) | https://github.com/CachyOS/linux-cachyos | kernel patches/scheduler tweaks (source of omen15's pinned cachyos-bore kernel input) |
| Pop!_OS | https://github.com/pop-os | kernel config-level hardening (`pop-os/linux`) |
| Whonix | https://github.com/Whonix (mirror) / https://gitlab.com/whonix (upstream) | hardening settings largely shared with Kicksecure |
| Tails | https://gitlab.tails.boum.org/tails/tails | sysctl / AppArmor / kernel hardening in `config/` + `features/` |
| Qubes OS | https://github.com/QubesOS | `qubes-linux-kernel`, `qubes-core-admin` (isolation/security-architecture reference) |
| secureblue | https://github.com/secureblue/secureblue | end-to-end hardening config (sysctl / udev / dconf) |
| Bazzite | https://github.com/ublue-os/bazzite | desktop/gaming sysctl + udev tuning (`system_files/desktop/shared`) — `vm.max_map_count`, inotify limits, scheduler udev rules |
| Kicksecure | https://github.com/Kicksecure | `security-misc` (full KSPP sysctl baseline in `990-security-misc.conf`), `hardened-kernel`, `tirdad` |
| nix-mineral | https://github.com/cynicsketch/nix-mineral | NixOS-native KSPP hardening module (sysctl / boot params / module blacklist; alpha). Heavily borrows from `security-misc` + nixpkgs `hardened.nix` — good cross-check for the sysctl baseline, and its `docs/CAVEATS.md`/`OMITTED.md` list what it deliberately skips and why |
| Pop!_OS (`default-settings`) | https://github.com/pop-os/default-settings | System76's own desktop sysctl/udev/modules-load/journald tuning (distinct from `pop-os/linux`, the kernel-config repo, which isn't automated — see "Kernel Kconfig hardening" in `docs/upstream-settings.md`) |
| GrapheneOS (`infrastructure`) | https://github.com/GrapheneOS/infrastructure | Server deployment scripts for GrapheneOS's own attestation/update servers — not their (Android-only) OS itself. The original source secureblue's `chrony.conf` was copied from; also has its own `sysctl.d` (mostly server-networking-context tuning, not general hardening advice) |

The main take-away sources are Kicksecure's `security-misc` (it implements the
KSPP recommended settings and is shared with Whonix) and Tails'/Qubes' own
hardening. The rest are mostly performance/desktop tuning references.

---

## License

[MIT](LICENSE) — feel free to fork and adapt.
