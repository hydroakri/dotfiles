# Upstream Settings Provenance

The kernel parameter / sysctl / udev / modprobe hardening under
`flake/modules/features/` in this repo is **adapted, not copied**, from
several upstream distributions (see README "Reference Sources"). This table
records where each setting group came from, its porting status, and when it
was last reviewed — it's the baseline the quarterly review (process at the
bottom of this file) diffs against.

## Status legend

| Status | Meaning |
|---|---|
| `ported` | Merged into a module in this repo and field-tested on at least one host |
| `partial` | Only some settings from that upstream source were taken |
| `reference-only` | Not ported yet, kept as a design/comparison reference |
| `tried-and-rejected` | Tried, caused a problem — see `known-breaking-settings.md` |

## Provenance table

| Setting group | Upstream source | Location in this repo | Status | Last reviewed |
|---|---|---|---|---|
| Baseline sysctl (kernel.* pointers/dmesg/bpf, net.* ARP/ICMP/redirects, fs.protected_* etc.) | Kicksecure `security-misc`'s `/usr/lib/sysctl.d/990-security-misc.conf` (KSPP recommended baseline) + ANSSI guide (R8/R9/R12/R33 in comments) | `security.nix` priority-950 block | Ported (modified: merged in ANSSI items, `ptrace_scope` lowered to 1, `io_uring_disabled` kept at 1 on desktop) | Not yet reviewed |
| Kernel boot params (slab_nomerge, lockdown, cfi, init_on_alloc, oops=panic…) | KSPP / nixpkgs `hardened.nix` / madaidans-insecurities (same lineage nix-mineral draws from) | `security.nix` `boot.kernelParams` | Ported | Not yet reviewed |
| Server strict-mode block (io_uring/perf/binfmt_misc fully disabled) | Kicksecure `security-misc` (server variant) + self-authored desktop/server split | `security.nix` priority-900 block | Ported | Not yet reviewed |
| I/O scheduler udev rules (kyber/mq-deadline/bfq), `hdparm -B 254 -S 0`, `cpu_dma_latency` group `audio` | CachyOS `CachyOS-Settings` `usr/lib/udev/rules.d/60-ioschedulers.rules` | `performance.nix` `services.udev.extraRules` | Ported (rules adapted from original) | Not yet reviewed |
| Performance sysctl (dirty_bytes, vfs_cache_pressure, page-cluster, watermark, min_free_kbytes…) | CachyOS `CachyOS-Settings` `usr/lib/sysctl.d/70-cachyos-settings.conf` | `performance.nix` `boot.kernel.sysctl` (vm.* block) | Ported (swappiness changed to 180, watermark/compaction etc. added) | Not yet reviewed |
| BBR + CAKE qdisc, TCP buffer tuning | CachyOS / general network tuning (fq_codel family) | `performance.nix` net.* block | Ported | Not yet reviewed |
| ananicy process priorities + cachyos rule set | CachyOS (ananicy-cpp + ananicy-rules-cachyos) | `performance.nix` `services.ananicy` | Ported | Not yet reviewed |
| zram-generator (ram/2, zstd) + zswap disabled | CachyOS default (systemd-zram-generator + CachyOS-Settings pairing) | `performance.nix` | Ported | Not yet reviewed |
| scx scheduler (scx_rusty) | CachyOS `linux-cachyos` (sched-ext family) | `performance.nix` `services.scx` | Ported | Not yet reviewed |
| snd-hda-intel AC/battery power management udev | CachyOS `CachyOS-Settings` udev rules | `powersave.nix` | Ported | Not yet reviewed |
| PCIe ASPM policy, `amd_pstate=active`, teo governor | CachyOS / TLP-style approach (self-authored udev script) | `powersave.nix` | Ported | Not yet reviewed |
| kloak (keystroke/mouse timing anonymization) | Whonix / kloak upstream (nixpkgs only ships the binary) | `privacy.nix` | Partial (self-written systemd unit + Wayland detection) | Not yet reviewed |
| IPv6 privacy addresses, MAC randomization | General baseline (also present in Kicksecure network hardening) | `privacy.nix` | Ported | Not yet reviewed |
| Kernel module blacklist | Kicksecure `security-misc` (bluetooth etc.) → also in nix-mineral | Not ported (only essential items disabled currently) | Reference-only | — |
| Full item-by-item sysctl comparison | nix-mineral, secureblue, Bazzite | `docs/upstream-vendor/diff_sysctl.py` — automated per-key diff against this repo's declared sysctl, not a decision on any individual key | Reference-only (tool) | 2026-08-11 |
| Kernel Kconfig hardening | Pop!_OS `linux`, Qubes `qubes-linux-kernel`, Kicksecure `hardened-kernel`, KSPP recommendations generally | — | Not pursued (removed 2026-08-11: this repo builds its own CachyOS kernel; acting on any Kconfig finding means maintaining kernel patches/`structuredExtraConfig`, not a one-line Nix change — not worth the maintenance burden) | — |
| AppArmor profile set | Tails `config/` (AppArmor hardening) | `security.nix` only enables nixpkgs' bundled profiles | Reference-only | — |
| Kernel config-level hardening | Pop!_OS `linux` / Qubes `qubes-linux-kernel` / Kicksecure `hardened-kernel` | Not ported (a NixOS kernel-config rebuild is a separate project; see Kconfig check above for what *is* automated) | Reference-only | — |
| secureblue full set (dconf/sysctl/udev) | `secureblue/secureblue` | sysctl: automated diff (see above). dconf/udev: not ported | Reference-only | — |
| Bazzite desktop/gaming sysctl + udev | `ublue-os/bazzite` `system_files/desktop/shared` | sysctl: automated diff (see above). udev: vendored, manual `diff -ru` | Reference-only | — |
| srvos (boot.tmp.cleanOnBoot etc.) | nix-community/srvos | `security.nix`, a few individual lines | Partial | Not yet reviewed |

## Review log

One row per settings decision. Vendored sources: CachyOS, Kicksecure,
secureblue, Bazzite, nix-mineral, Pop!_OS `default-settings`, GrapheneOS
`infrastructure` (7 total). Tooling and process notes (bugs fixed, sources
checked and rejected, coverage methodology) live in
`docs/upstream-vendor/README.md`, not here.

### 2026-08-11

| Item | Tradeoff |
|---|---|
| `net.core.netdev_max_backlog` 2048 → 4096 | Buffer size, no downside on modern RAM |
| `fs.inotify.max_user_instances` 1024 → 8192 | Dev tools/games exhaust the default; cost negligible |
| `vm.mmap_rnd_bits` unchanged | Tool false positive — arch-conditional (32 x86_64/24 aarch64), omen15 already 32 |
| `kernel.oops_limit`/`warn_limit` kept 100 | nix-mineral's `1` would reboot the machine on routine driver hiccups |
| `kernel.yama.ptrace_scope` kept 1 | `3` broke Steam (documented); GrapheneOS's `2` untested, not worth the risk |
| `vm.swappiness` kept 180 | Tied to zram-generator sizing |
| `net.ipv4.tcp_sack` kept on | CVEs motivating "off" patched since 2019; off only costs perf now |
| `net.ipv4.tcp_tw_reuse` kept on | Safe with `tcp_timestamps` on (already the case); NAT-collision risk doesn't apply to single-user client |
| `net.ipv6.conf.*.accept_ra` kept 2 | `rpi4-switch` needs it for IPv6 prefix delegation; risking the router's IPv6 for unverified upside isn't worth it |
| `vm.dirty_background_bytes` kept 128MB | Bazzite + Pop!_OS (closer workload match) both agree |
| `vm.max_map_count` 1048576 → 2147483642 | Bazzite *and* Pop!_OS both default to it (not gaming-specific); soft ceiling, no upfront cost |
| `net.ipv4.ip_forward`/ipv6 forwarding unchanged | Already router.nix-only by design, not a global setting |
| `services.usbguard.presentDevicePolicy` `keep` → `allow` | Matches Kicksecure default |
| `services.usbguard.IPCAllowedGroups` unchanged (empty) | `IPCAllowedUsers` already covers the main user |
| `PermitRootLogin` kept `prohibit-password` | Already key-only; full disable risks breaking an unconfirmed root-SSH workflow |
| `journald` `SystemMaxUse` kept 64M | Pure disk-usage/retention tradeoff, not security |
| SSH server crypto (`Ciphers`/`KexAlgorithms` narrowed, `HostKeyAlgorithms`/`PubkeyAcceptedAlgorithms` ed25519-only, `HostKey` restricted) | Kicksecure sshd_config.d; `Macs` left undeclared — NixOS's own curated default already matches |
| SSH server session/banner hardening (`AllowAgentForwarding`/`Compression`/`TCPKeepAlive`=false, `MaxAuthTries`/`MaxSessions`/`ClientAliveCountMax`, `DebianBanner`/`PrintMotd`=false, `UsePAM`=true) | Low/no functional cost on a single-user machine |
| SSH client mirrors server crypto + `VisualHostKey=yes` | Same reasoning as server |
| `security.pam.loginLimits` coredump=0 + memlock≈2GB (new) | Complements existing coredump ban; lets GPG/password managers lock memory out of swap |
| `@audio` realtime ulimit declined | `security.rtkit.enable` (already on) is the modern per-process equivalent with a watchdog |
| `systemd.tmpfiles.rules` THP tuning (new) | Doesn't duplicate existing `transparent_hugepage=madvise` — that's *whether*, this is *how* |
| DMI `product_serial` permission → root/wheel (new) | Device-fingerprinting vector, no functional cost |
| `DefaultLimitNOFILE` raised (system+user, new) | Same "dev tools/games exhaust default" reasoning as inotify |
| `DumpCore=false` (system+user, new) | Consistent with existing full coredump ban |
| `DefaultTimeoutStartSec`/`StopSec` 90s kept | No reason to risk killing a legitimately slow-starting service |
| pstore `Storage=none` (new) | Echoes existing `erst_disable` kernel param |
| NetworkManager `ipv6.ip6-privacy=2` (new) | Guards against a known NM-version bug where global sysctl inheritance doesn't apply reliably |
| `main.dns=dnsconfd` declined | Fedora/rpm-ostree-specific, not available on NixOS |
| resolved `LLMNR=false` declined | Moot — `services.resolved.enable` defaults off and stays off here |
| `boot.blacklistedKernelModules`, 769 modules (new) | Legacy/obscure hardware (DVB/TV tuners, old framebuffers, gameport joysticks, FireWire, RDMA, obscure net protocols, `evbug`, fuzzing-prone legacy filesystems) — attack surface with no real usage here |
| Excluded from blacklist: CAN, NFS/CIFS, Thunderbolt, Bluetooth (`bluetooth`/`btusb`), `joydev`, RNDIS | Each has plausible real use on this host (NAS mounts, eGPU/dock, BT peripherals, modern USB controllers via the legacy joystick API, phone USB tethering) |
| `nf_conntrack_helper=0` (new) | Standard hardening, no functional cost |
| chrony `minsources` → 2 (asked 3) | Cross-source agreement without being overly strict given 7 configured sources |
| chrony `authselectmode prefer` (new) | Prioritizes NTS sources; kept over stricter `require` both times it came up (secureblue and GrapheneOS variants) since one configured server is non-NTS |
| chrony `dscp`/`dumpdir`/`leapseclist`/`rtcsync` bundle (new) | Low-risk operational/precision improvements |
| chrony +3 NTS servers (new) | Confirmed secureblue-sourced like the rest before adding, not mixed-provenance |
| chrony `cmdport 0` declined | Would disable local `chronyc` diagnostics |
| chrony `enableRTCTrimming=false` (new, required) | Conflicts with `rtcsync` above — NixOS won't build with both on |
| chrony `extraFlags` seccomp + dump-reload (new) | Mature/stable chrony feature; low risk |
| `zram-generator` size capped at 16GB (new) | Diminishing returns above that on a high-RAM machine |
| Bluetooth daemon hardening bundle (timeouts, `MaxControllers`, `Privacy=network/on`, `AutoEnable=false`, `powerOnBoot=false`) | Driver stays loaded (see blacklist above); this tightens daemon behavior instead, no functional loss |
| `faillock.conf`/`pwquality.conf` declined | Key-based auth here, not password; `pwquality` ships `enforcing=0` even upstream |
| `access.conf` (console-only login) declined | Public/shared-terminal threat model, not a personal laptop's |
| `gpg.conf` adopted into `dot_gnupg/` (chezmoi, not flake) | Per-user app config, not system policy; cheap to have ready even though GPG isn't in daily use |
| `kyber-iosched` added to `boot.kernelModules` (new) | Existing udev rule assigning it to NVMe disks may have been silently failing without the module loaded |
| `boot.kernelParams "nohibernate"` (new) | Hibernation already non-functional here (`lockdown=confidentiality` + zram); free to make explicit |
| bpf_jit_enable/redirect+martian+rp_filter sysctls/AppArmor/`unprivilegedUsernsClone`/`allowed-users` — no gap | Already covered by an existing, more nuanced or equal/stricter setting |
| `kernel.ftrace_enabled=false` declined | Kills `perf`/tracing tools; `perf` access already gated by `perf_event_paranoid` |
| `page_poison=1` declined | Kernel-dev debugging aid, real perf cost, little end-user benefit |
| `security.lockKernelModules=true` declined | Breaks post-boot driver loading; consistent with device-compat calls made elsewhere this session |
| `nosmt` declined | Major perf cost on a performance-tuned machine for a mitigation NixOS's own docs call "unproven" |
| `pti=on` (force KPTI) declined | Zero benefit on Meltdown-immune modern CPUs; conflicts with existing `mitigations=auto` |
| `flushL1DataCache` not applicable | Only relevant as a hypervisor; `libvirtd` is off |
| Per-service systemd sandboxing (`ProtectSystem` etc.) deferred | Different axis (per-service, not system-wide), substantial enough for its own pass |
| `net.mptcp.enabled=0` (new) | Unused protocol on this desktop; one less parser in the attack surface |
| `vm.memfd_noexec=1` (new) | Modern anti-fileless-malware mitigation; mainstream distros converging on it |

## Quarterly review process (Plan A: manual)

Run this once per quarter, on the last weekend of the quarter (worth a
calendar reminder):

1. **Fetch upstream** (shallow clone into `/tmp/upstream-review/`):
   `Kicksecure/security-misc`, `Kicksecure/hardened-kernel`,
   `secureblue/secureblue`, `CachyOS/CachyOS-Settings`,
   `tails/tails` (gitlab.tails.boum.org), `cynicsketch/nix-mineral`
2. **Diff the key files**: `990-security-misc.conf`,
   `70-cachyos-settings.conf`, nix-mineral's `settings/`, Tails' `config/`,
   against the previous review's notes
3. **Update this table**: fill in the "Last reviewed" date and the
   upstream version/commit; tag any newly appeared settings per the status
   legend
4. **Experiment with each candidate change individually**: roll out from
   lowest-risk host first, **oci → rpi → omen15**; run
   `nixos-rebuild build` before switching on each; record every
   conclusion (kept/rejected) in `known-breaking-settings.md`
5. **Merge**: only merge settings that have actually been tested; update
   README "Reference Sources" if any new source was added
