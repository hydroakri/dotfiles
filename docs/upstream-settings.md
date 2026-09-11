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
| Baseline sysctl (kernel.* pointers/dmesg/bpf, net.* ARP/ICMP/redirects, fs.protected_* etc.) | Kicksecure `security-misc`'s `/usr/lib/sysctl.d/990-security-misc.conf` (KSPP recommended baseline) + ANSSI guide (R8/R9/R12/R33 in comments) | `security.nix` priority-950 block | Ported (modified: merged in ANSSI items, `ptrace_scope` lowered to 1, `io_uring_disabled` kept at 1 on desktop) | 2026-08-12 |
| Kernel boot params (slab_nomerge, lockdown, cfi, init_on_alloc, oops=panic…) | KSPP / nixpkgs `hardened.nix` / madaidans-insecurities `guides/linux-hardening.html` (directly reviewed 2026-09-11, previously only cited indirectly via nix-mineral's lineage) | `security.nix` `boot.kernelParams` | Ported (2026-08-12: fixed `iommu=strict`→`iommu.strict=1` bug; `amd_iommu=force_isolation` tried, caused a kernel panic, reverted — see `known-breaking-settings.md`. 2026-09-11: direct-source audit found no new boot-param gaps — see Review log) | 2026-09-11 |
| Server strict-mode block (io_uring/perf/binfmt_misc fully disabled) | Kicksecure `security-misc` (server variant) + self-authored desktop/server split | `security.nix` priority-900 block | Ported | 2026-08-12 |
| I/O scheduler udev rules (kyber/mq-deadline/bfq), `hdparm -B 254 -S 0`, `cpu_dma_latency` group `audio` | CachyOS `CachyOS-Settings` `usr/lib/udev/rules.d/60-ioschedulers.rules` | `performance.nix` `services.udev.extraRules` | Ported (rules adapted from original; `40-hpet-permissions.rules`/`50-sata.rules` also ported 2026-08-12, `71-nvidia.rules` ported into `nvidia.nix`) | 2026-08-12 |
| Performance sysctl (dirty_bytes, vfs_cache_pressure, page-cluster, watermark, min_free_kbytes…) | CachyOS `CachyOS-Settings` `usr/lib/sysctl.d/70-cachyos-settings.conf` | `performance.nix` `boot.kernel.sysctl` (vm.* block) | Ported (swappiness changed to 180, watermark/compaction etc. added) | 2026-08-12 |
| BBR + CAKE qdisc, TCP buffer tuning | CachyOS / general network tuning (fq_codel family) | `performance.nix` net.* block | Ported | 2026-08-12 |
| ananicy process priorities + cachyos rule set | CachyOS (ananicy-cpp + ananicy-rules-cachyos) | `performance.nix` `services.ananicy` | Ported (live nixpkgs dependency, not a static snapshot — self-updating) | 2026-08-12 |
| zram-generator (ram/2, zstd) + zswap disabled | CachyOS default (systemd-zram-generator + CachyOS-Settings pairing) | `performance.nix` | Ported | 2026-08-12 |
| scx scheduler (scx_rusty) | CachyOS `linux-cachyos` (sched-ext family) | `performance.nix` `services.scx` | Ported (not diffable — `linux-cachyos` isn't part of the vendored `CachyOS-Settings` snapshot) | 2026-08-12 |
| snd-hda-intel AC/battery power management udev | CachyOS `CachyOS-Settings` udev rules | `powersave.nix` | Ported (confirmed intentional simplification vs. upstream — hardcoded value instead of captured-default restore) | 2026-08-12 |
| PCIe ASPM policy, `amd_pstate=active`, teo governor | CachyOS / TLP-style approach (self-authored udev script) | `powersave.nix` | Ported (confirmed self-authored — no matching file in vendored `cachyos` snapshot) | 2026-08-12 |
| systemd Manager tuning: `pci-latency.service`, `user@.service.d` cgroup delegate, `rtkit-daemon` log cap | CachyOS `CachyOS-Settings` `usr/lib/systemd/system/{pci-latency.service,user@.service.d/delegate.conf,rtkit-daemon.service.d/override.conf}` | `performance.nix` | Ported (`DefaultTimeoutStartSec`/`StopSec` and `DefaultLimitNOFILE` from the same upstream `.conf.d` pair were already decided separately — see 2026-08-11 review log) | 2026-09-11 |
| CachyOS CLI tools (`kerver`) | CachyOS `CachyOS-Settings` `usr/bin/{kerver,game-performance,zink-run}` | `performance.nix` `environment.systemPackages` | Partial (`game-performance`/`zink-run` ported then removed 2026-09-11 — redundant with existing `gamemode`+`steamtinkerlaunch`; `topmem` declined; `dlss-swapper`/`dlss-swapper-dll` declined — see Review log) | 2026-09-11 |
| kloak (keystroke/mouse timing anonymization) | Whonix / kloak upstream (nixpkgs only ships the binary) | `privacy.nix` | Partial (self-written systemd unit + Wayland detection) | Not reviewable (kloak upstream not among the 8 vendored sources) |
| IPv6 privacy addresses, MAC randomization | General baseline (also present in Kicksecure network hardening) | `privacy.nix` | Ported | 2026-08-12 |
| Unbound resolver hardening (`hide-identity`/`hide-version`, `aggressive-nsec`, `harden-large-queries`, `use-caps-for-id`, `private-address` DNS-rebinding block) | OpenBSD `etc/unbound.conf` (base structure) + secureblue `unbound/conf.d` (`harden-large-queries`/`use-caps-for-id`) + GrapheneOS `infrastructure` `etc/unbound/unbound.conf` (`tls-cert-bundle`/`private-address`) | `core.nix` `services.unbound.settings.server` | Ported | 2026-08-12 |
| DoT forward-zone: single vs. multi-provider pool | secureblue's `dnsconfd`/`dns_selector.py` picks exactly one provider (+ same-provider secondary IP) | `privacy.nix` `forward-zone` | Reference-only — kept existing 5-provider pool | 2026-08-12 |
| Kernel module blacklist | Kicksecure `security-misc` (bluetooth etc.) → also in nix-mineral | Not ported (only essential items disabled currently) | Reference-only | 2026-08-12 |
| Full item-by-item sysctl comparison | nix-mineral, secureblue, Bazzite | `docs/upstream-vendor/diff_sysctl.py` — automated per-key diff against this repo's declared sysctl, not a decision on any individual key. Known blind spot: only scans `flake/modules/features/*.nix`, misses `desktop.nix`/`server.nix` | Reference-only (tool) | 2026-08-13 |
| Kernel Kconfig hardening | Pop!_OS `linux`, Qubes `qubes-linux-kernel`, Kicksecure `hardened-kernel`, KSPP recommendations generally | — | Not pursued (removed 2026-08-11: this repo builds its own CachyOS kernel; acting on any Kconfig finding means maintaining kernel patches/`structuredExtraConfig`, not a one-line Nix change — not worth the maintenance burden) | — |
| AppArmor profile set | Tails `config/` (AppArmor hardening) | `security.nix` only enables nixpkgs' bundled profiles | Reference-only — Tails is now the 9th vendored source, reviewed; mostly Tor/onionshare/Debian-FHS specific, not portable. `attach_disconnected` (relevant for `preservation.nix` bind-mounts) tried and reverted — see Review log | 2026-08-12 |
| Kernel config-level hardening | Pop!_OS `linux` / Qubes `qubes-linux-kernel` / Kicksecure `hardened-kernel` | Not ported (a NixOS kernel-config rebuild is a separate project; see Kconfig check above for what *is* automated) | Reference-only | — |
| secureblue full set (dconf/sysctl/udev) | `secureblue/secureblue` | sysctl: automated diff (see above). udev: `50-usb-realtek-net.rules` tried then reverted (`performance.nix`), U2F handled via `services.udev.packages=[pkgs.libfido2]` instead of vendoring `70-u2f.rules`, `51-android.rules` declined (nixpkgs judges it superseded by systemd uaccess). dconf: not applicable (niri, not GNOME) | Reference-only | 2026-08-13 |
| Bazzite desktop/gaming sysctl + udev | `ublue-os/bazzite` `system_files/desktop/shared` | sysctl: automated diff (see above). udev: manually reviewed 2026-08-12, no unreviewed non-hardware-variant items remaining | Reference-only | 2026-08-13 |
| srvos (boot.tmp.cleanOnBoot etc.) | nix-community/srvos | `security.nix`, a few individual lines | Partial (not a flake input — one-time hand-adapted reference, no live source to diff against) | 2026-08-12 |

## Review log

One row per settings decision. Vendored sources: CachyOS, Kicksecure,
secureblue, Bazzite, nix-mineral, Pop!_OS `default-settings`, GrapheneOS
`infrastructure`, OpenBSD, Tails (9 total). Tooling and process notes (bugs fixed,
sources checked and rejected, coverage methodology) live in
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

### 2026-08-12

| Item | Tradeoff |
|---|---|
| `do-ip6` kept `true` | Matches OpenBSD default; avoids dead IPv6 `forward-addr` entries |
| `harden-large-queries`/`use-caps-for-id` (new) | secureblue baseline; free on TLS-only forwarding |
| `private-address` DNS-rebinding block (new, all hosts) | GrapheneOS `infrastructure`; only filters upstream answers, not a host's own binding |
| `tls-cert-bundle` explicit line declined | Already `mkDefault config.security.pki.caBundle` in nixpkgs' `unbound.nix` |
| DoT forward-zone kept at 5 providers | secureblue narrows to one; diversity preferred over exposure here |
| OpenBSD added as 8th vendored source (`etc/` sparse checkout) | Only real hand-written `unbound.conf` in the vendor set; full `src` clone is ~1.6GB |

### 2026-08-12 (continued: full `diff_sysctl.py`/`diff_misc.py` sweep + manual udev/systemd-service review)

Note: `grapheneos-infra` is GrapheneOS's own **server** infrastructure
(`github.com/GrapheneOS/infrastructure` — attestation/app-repo/update
servers), not Android device config. Rows below citing it as "server"
reflect that; earlier drafts of this review mislabeled some of it as
mobile/handset tuning.

| Item | Tradeoff |
|---|---|
| `kernel.watchdog=0` (new, `powersave.nix`) | Same intent as existing `kernel.nmi_watchdog=0`; bazzite |
| `net.ipv4.conf.default.drop_gratuitous_arp=1` (new) | `.all.` was already set, `.default.` was a gap next to paired `log_martians`/`rp_filter`; nix-mineral |
| `net.ipv6.icmp.echo_ignore_{anycast,multicast}=1` (new, global) | Completes existing full ping-silence posture (both `icmp_echo_ignore_all` variants already set); doesn't affect NDP (type 135/136, not echo); nix-mineral |
| `abi.vsyscall32=0` (new, flagged) | Same family as already-running `vsyscall=none` (no recorded Steam breakage); narrower scope, marked for a real test pass before treating as settled |
| `kernel.unprivileged_userns_clone=1` (new, explicit) + removed `security.unprivilegedUsernsClone=lib.mkDefault false` | That NixOS option only acts when `true` (sets the sysctl); at `false` it does nothing — dead/misleading line. Real value was riding the kernel's own default (verified `1` on omen15's cachyos-bore-lto kernel); podman needs it, now pinned explicitly |
| `net.ipv4.tcp_shrink_window=1` (new, `performance.nix`) | Memory-pressure receive-window shrink, no observed downside |
| `NVreg_EnableS0ixPowerManagement=1` (new, `nvidia.nix`) | omen15 measured `[s2idle] deep` in `/sys/power/mem_sleep` — GPU actually goes through S0ix; bazzite |
| `71-nvidia.rules` unbind→`on` restore only (new, `nvidia.nix`) | The bind→`auto` half is already covered by `powersave.nix`'s generic `SUBSYSTEM=="pci", ATTR{power/control}="auto"` rule; only the unbind-restore direction was a real gap; cachyos |
| `journald.ForwardToWall=no` (new) | Only stops emerg-priority wall broadcast to other terminals; doesn't affect `journalctl`/log content; Kicksecure |
| `journald.Storage=persistent` (new) | Was `auto`; forces disk-backed logs across reboots; Kicksecure |
| `usbguard.implicitPolicyTarget=block` / `presentControllerPolicy=keep` / `deviceRulesWithPort=false` (new) | Kicksecure defaults; NixOS module exposes these as typed options |
| `usbguard.AuthorizedDefault`/`HidePII` declined | NixOS's `services.usbguard` module has a closed hand-templated config with no passthrough — these two keys aren't exposed at all; would require fully bypassing the module (custom `ExecStart`) for two likely-already-default values |
| `rescue.service`/`emergency.service` `SYSTEMD_SULOGIN_FORCE=1` (new) | Requires root password at rescue/emergency shell instead of dropping to unauthenticated root; Kicksecure |
| `-.slice` `MemoryLow`/`MemoryMin=64M` (new) | Not a NixOS default (only set when `systemd-oomd` is on, which it isn't here) — pure cgroup memory floor, no oomd dependency; grapheneos-infra |
| `sshd` `LimitNOFILE=8192` + `Restart=always` w/ backoff (new) | Low-risk; dropped grapheneos-infra's `ManagedOOMPreference=avoid` since `systemd.oomd.enable=false` here |
| `fstrim` `interval=daily` + idle CPU/IO scheduling (new) | Default was `weekly` with no scheduling override from either NixOS or util-linux's shipped unit; grapheneos-infra |
| `unbound.service` `Restart=always` w/ backoff only (new) | secureblue's extra sandboxing (`ProtectSystem=strict` etc.) declined — NixOS's own `unbound.nix` module already matches or exceeds it; only the restart-backoff addition (grapheneos-infra) was a real gap |
| `40-hpet-permissions.rules` (new, `performance.nix`) | `rtc0`/`hpet` → `audio` group; same risk class as already-ported `cpu_dma_latency`→`audio`; cachyos |
| `50-sata.rules` ALPM `max_performance` (new, `performance.nix`) | Self-limiting match condition (`link_power_management_supported=="1"`); omen15 has no internal SATA (pure NVMe, verified via `lsblk`), but a USB-SATA external HDD is in use — no downside either way |
| `50-usb-realtek-net.rules` — tried, reverted | Not worth carrying 24 vendor-ID entries for one device; secureblue |
| U2F/FIDO via `services.udev.packages = [ pkgs.libfido2 ]` (new) instead of secureblue's `70-u2f.rules` | `libfido2` was already in `environment.systemPackages` but its bundled udev rules were never registered — upstream-maintained package rules preferred over vendoring secureblue's copy |
| `51-android.rules` declined | nixpkgs removed its own `android-udev-rules` package: "superseded by built-in systemd uaccess rules" |
| `titan-key.rules` extra Feitian-OEM IDs (`096e:0858`/`085b`) declined | Confirmed Google-branded key (`18d1:5026`), already covered by `libfido2`'s bundled rules |
| `server.nix`: `tcp_ecn=0`/`tcp_syn_retries=4`/`tcp_synack_retries=3`/`tcp_orphan_retries=6`/`tcp_retries2=8` (new) | Server self-protection against half-open-connection resource exhaustion; `oci` is the relevant case (nginx fronting headscale/vaultwarden/searx/atticd/ntfy-sh on 80/443) — also applies to `rpi4-switch`/`rpi4-side-gateway` as fellow `server.nix` importers; grapheneos-infra |
| `server.nix`: `tcp_fin_timeout=30`/`tcp_notsent_lowat=131072`/`nf_conntrack_tcp_timeout_established=1800` at `mkOverride 900` (new) | Accommodates many/unstable external client connections on `oci`; grapheneos-infra. `ip_local_port_range` excluded — ANSSI attack-surface reduction wins over server port-capacity |
| `server.nix` existing `netdev_max_backlog`/`rmem_max`/`wmem_max`/`tcp_rmem`/`tcp_wmem`/`tcp_mem` (`mkDefault`) left as-is, commented | Pre-existing dead code, 6 lines not 5 as first flagged (missed `netdev_max_backlog` in the initial pass) — all lose to `performance.nix`'s `mkOverride 950`, never took effect. No strong case for `oci`'s current traffic level to need smaller values; kept inert rather than silently deleted |
| GrapheneOS conntrack/buffer cluster declined for desktop/router (`net.core.rmem_max`↓, `ip_local_port_range` wide, etc. as a blanket change) | Workload mismatch for `omen15`/`rpi4-*` outside what's covered above for `oci`-relevant `server.nix` rows |
| `kernel.sysrq=0` declined | `core.nix` already sets `kernel.sysrq=246` — a curated safe subset, not the kernel default; not the blunt on/off Kicksecure/secureblue propose |
| `dev.cdrom.*=0` declined | No optical drive hardware |
| `kernel.io_uring_group`/`net.core.devconf_inherit_init_net`/`dev.raid.speed_limit_{max,min}` declined | No gid-scoped io_uring use, no netns/container-heavy deployment matching the scenario, no mdadm RAID anywhere in the repo |
| `amdgpu`/`radeon` `si_support`/`cik_support` declined | Targets 2012–2014 GCN 1.0/2.x cards; wrong hardware generation |
| grapheneos-infra `modules-load.d` set (`bonding`/`dm_crypt`/`nft_*`/`sch_fq`/`softdog`/`veth`/`vfat`) declined | No bonded NICs, no LUKS, no real `nftables` ruleset (`networking.nftables.enable` is `false`); `softdog` directly conflicts with existing `nowatchdog`+`nmi_watchdog=0`; `veth`/`vfat` low-value autoload-anyway preloads |
| `libno_rlimit_as.so` declined | No NixOS package; self-packaging cost disproportionate to a companion shim for hardened malloc |
| `systemd-boot-update.service` `SYSTEMD_RELAX_ESP_CHECKS=1` declined | GrapheneOS OEM-specific ESP-check workaround; no corresponding issue here |
| `85-iw-regulatory.rules` + companion service declined (whole mechanism) | Auto-detects WiFi regulatory domain from timezone; `core.nix` hardcodes `time.timeZone="UTC"`, and the script itself no-ops on UTC — permanently defeated by an existing deliberate setting |
| `95-emerg-shutdown.rules` + `emerg-shutdown.service` declined (whole mechanism) | Force-shutdown on boot-media removal, for portable/live-USB installs (Tails-style anti-forensics); none of the 4 hosts are portable installs |
| Tails' `attach_disconnected` AppArmor flag (via `apparmor-profiles.overrideAttrs`) — tried, reverted | nixpkgs' own profile set curates a per-profile exception list for this flag; blanket-applying it removes a real anti-namespace-escape protection repo-wide. Defer until an actual `preservation.nix`-triggered denial shows up |
| `DebianBanner=false` not re-added | Debian-only sshd_config patch, not present in nixpkgs' vanilla OpenSSH — see `known-breaking-settings.md` |
| `kernel.printk="3 3 3 3"` relocation to `security.nix` declined | Stays in `desktop.nix` bundled with quiet-boot/plymouth UX; `oci`/`rpi4-*` (`server.nix`) remain without it — known gap, not fixed this round |
| tmpfiles/coredump overlap (secureblue 3-day cleanup rule, `coredump.conf.d Storage=none`) — documented only, no config change | Already triple-banned via `core_pattern`/`DumpCore=false`/ulimit `core=0`; these two are very likely no-ops |
| `diff_sysctl.py` blind spot noted (see `docs/upstream-vendor/README.md`) | Only scans `flake/modules/features/*.nix`; misses `desktop.nix`/`server.nix`, which is why `kernel.printk` false-flagged as "not ported" despite being set in `desktop.nix` |

### 2026-08-12 (continued: `boot.kernelParams` manual review — not covered by `diff_sysctl.py`, which only parses `key = value` sysctl)

| Item | Tradeoff |
|---|---|
| `iommu=strict` → `iommu.strict=1` (bugfix) | `iommu=strict` isn't a real kernel parameter — the generic IOMMU layer's flag is dot-namespaced. Confirmed via `dmesg`: `iommu: DMA domain TLB invalidation policy: lazy mode` before the fix, i.e. this line never worked since it was added. See `known-breaking-settings.md` |
| `amd_iommu=force_isolation` — tried, kernel panic on boot, reverted | See `known-breaking-settings.md` |
| `init_on_free=1` declined | Pairs with `init_on_alloc=1`; roughly doubles that cost, not worth it |
| `hardened_usercopy=1` declined | No-op — `CONFIG_HARDENED_USERCOPY_DEFAULT_ON=y` already on |
| Kicksecure's per-CVE mitigation series (`spectre_v2=on`, `l1tf=*`, `kvm-intel.*`, `mds=*`, `tsx=off`, `mmio_stale_data=*`, `retbleed=*`, `gather_data_sampling=force`, `reg_file_data_sampling=on`, `indirect_target_selection=force`, `vmscape=force`) declined as a block | Mostly Intel/KVM-only (`libvirtd` off); trusts `mitigations=auto` over hand-picking |
| `nosmt`, `kpti=1`/`pti=on`, `slab_debug=FZ` (Kicksecure) | Already declined 2026-08-11 |
| `intel_iommu=on` declined | omen15 is AMD |
| `ia32_emulation=0` declined | Would break 32-bit Steam/Proton |
| PCIe ACS override patch — not pursued | Not in any vendored source; revisit if VFIO setup hits a bad IOMMU group |
| `lockdown=confidentiality`→`integrity`, still inert | See `known-breaking-settings.md` |
| `ima_policy=tcb` — not adopted | Real option (measure-only, `CONFIG_IMA_APPRAISE` absent), left for later |
| `cfi=kcfi`, `extra_latent_entropy` — inert, kept | See `known-breaking-settings.md` |
| `proc_mem.force_override=ptrace` — deliberate downgrade from compiled default | See `known-breaking-settings.md` |

### 2026-08-12 (continued: remaining "not yet reviewed" provenance rows — ananicy/zram/scx/kloak/MAC-randomization/srvos, none diffable by `diff_sysctl.py`)

| Item | Tradeoff |
|---|---|
| Performance sysctl (`vm.*` block) / BBR+CAKE+TCP tuning — no new gaps | `diff_sysctl.py` re-confirmed: only 4 `DIFFERS`, all already decided in the 2026-08-11 log (`vm.dirty_background_bytes`, `vm.max_map_count`, `vm.mmap_rnd_bits` arch-conditional false positive, `vm.swappiness`) |
| ananicy rule set — no static diff needed | `pkgs.ananicy-rules-cachyos` is a live nixpkgs dependency, not a vendored snapshot — it tracks upstream automatically by construction |
| zram-generator size/algorithm — no new gap | Already-decided 16GB cap (2026-08-11) vs. cachyos's uncapped `ram`; `compression-algorithm=zstd` matches |
| cachyos `30-zram.rules`' inline `SYSCTL{vm.swappiness}="150"` not ported | Redundant re-assertion at zram-device-init time (vs. this repo's boot-time `mkOverride 950` sysctl); different value anyway (150 vs. our deliberate 180) so porting it would just fight the existing sysctl — low-stakes, not pursued |
| scx scheduler — not diffable | `linux-cachyos`/sched-ext isn't in the vendored `cachyos` snapshot (that's `CachyOS-Settings`, a different repo); no local vendor content exists to compare `scx_rusty` against |
| snd-hda-intel udev — confirmed intentional simplification, not a gap | This repo hardcodes `power_save=1` on battery / `0` on AC; cachyos's `20-audio-pm.rules` instead captures the driver's actual shipped default on first boot and restores *that* on battery. Simpler and deliberate-looking; the AC (anti-crackle) behavior — the one that actually matters day-to-day — is identical either way |
| PCIe ASPM/`amd_pstate=active`/teo governor (`powersave.nix`) — confirmed self-authored, not diffable | No file in the vendored `cachyos` snapshot mentions `amd_pstate`, `pcie_aspm`, or `cpuidle`; provenance table's "self-authored udev script" attribution is accurate, nothing to compare against |
| kloak — not reviewable with current tooling | kloak's own upstream repo was never vendored (only nixpkgs' binary package is used); none of the 8 `refresh.sh` sources is kloak itself. Would need a 9th vendor source to do a real diff |
| IPv6 privacy addresses / MAC randomization — no gap | `wifi.macAddress`/`wifi.scanRandMacAddress`/`ethernet.macAddress` (desktop-only) already comprehensively set in `privacy.nix:157-160`; initial "not yet reviewed" tag was stale, not an actual gap |
| srvos — no live source to diff against | Not a flake input (`flake.nix`/`flake.lock` confirmed no `srvos` entry); `boot.tmp.cleanOnBoot` etc. were a one-time hand-adapted reference, not an ongoing dependency |

### 2026-08-12 (continued: fresh full `*.d` directory re-audit across all 9 sources, prompted by a completeness check)

| Item | Tradeoff |
|---|---|
| `networking.firewall.extraCommands`: `ip46tables -P INPUT DROP` (new) | NixOS's own iptables `firewall.service` never sets a base INPUT policy — all filtering lives in the `nixos-fw` chain reached via one jump rule, which `stopScript` removes on shutdown (`conflicts=shutdown.target`), leaving INPUT's default ACCEPT policy exposed until the machine actually powers off. Same failure class as Tails' `ferm.service.d` fix (tails#20536). Fail-closed fallback, verified in the built script to run before the jump rule is added — no effect on normal operation |
| `dbus-broker.service.d` (pop-default-settings: `Restart=on-failure`, `LimitNOFILE` bump) declined | Not pursued this round |
| Tails' remaining ~40 newly-enumerated `*.d` categories (GNOME services, Tor/onion-grater, live-boot hooks, dconf, app-specific D-Bus policy) | Confirmed N/A — niri not GNOME, no Tor, permanent install not live-boot |

### 2026-08-13 (day-after check-in: `git ls-remote` on all 9 branches, `refresh.sh` + diff scripts only for the ones that moved)

| Item | Tradeoff |
|---|---|
| secureblue/bazzite/grapheneos-infra moved since 2026-08-12; other 6 sources unchanged | Diffed via GitHub compare, not a full re-vendor: bazzite = README only, grapheneos-infra = `rbl.conf` domain reorder (no new domains), secureblue = CI/scripts + the two rows below. `diff_sysctl.py`/`diff_misc.py` re-run: no output differs from 2026-08-11/12 |
| chrony `-F 1` (SCFILTER) removed from `extraFlags` (`core.nix`) | Crash-looping `chronyd` on every host (SIGSYS) — its compiled-in seccomp allowlist assumes glibc + glibc malloc; `pkgsMusl.chrony` links musl + `libhardened_malloc-light.so`. `-r` kept |
| `preservation.nix`: `/var/lib/chrony` given explicit `user`/`group`/`mode` | Was inheriting the module's blanket `0755 root:root`, silently overriding the NixOS chrony module's own `0750 chrony:chrony` tmpfiles rule — blocked new-file creation. Rest of the `directories` list swept for the same bug class, chrony was the only real mismatch |
| secureblue's new `bash-timeout.sh` (server `TMOUT=300`, idle shell auto-logout) declined | Real candidate for `server.nix`; no `TMOUT` set anywhere currently |
| Unrelated: `nix flake check` fails on `packages.x86_64-linux.iso-installer` (`plasma6` vs `niri` `defaultSession` conflict) | Pre-existing, not from this review; not fixed here |

### 2026-09-11 (triggered by a third-party Nix port, cross-checked against our own vendored upstream instead of trusted directly)

`github.com/vivekanandan-ks/ksv-cachyos-settings-nixos` is a separate Nix
port of `CachyOS-Settings`. Rather than trusting its output, every file it
referenced was diffed against this repo's own vendored copy
(`docs/upstream-vendor/cachyos`, commit `aba2ea7`) and confirmed
byte-identical — the port itself introduced no new upstream content, it just
surfaced settings groups this repo hadn't reviewed yet.

| Item | Tradeoff |
|---|---|
| `pci-latency.service` (new, `performance.nix`) | Not previously reviewed; low-risk oneshot `setpci` call, fixes the same audio-latency-relevant PCI timer defaults cachyos ships |
| `user@.service.d` cgroup `Delegate` (new, `performance.nix`) | Not previously reviewed; lets the user session manager (gamescope etc.) manage `cpu`/`cpuset`/`io`/`memory`/`pids` controllers |
| `rtkit-daemon` `LogLevelMax=info` (new, `performance.nix`) | Not previously reviewed; pure log-noise reduction, no functional effect |
| `kerver` diagnostic script (new, `performance.nix`) | Kernel/microarch/active-scheduler dump tool; packaged as `writeShellScriptBin`, smoke-tested on omen15 (correctly reported cachyos-bore-lto kernel + scx state) |
| `game-performance` wrapper — ported, then removed same day | Redundant: `gamemode.settings.general.desiredprof = "performance"` (already in `gaming.nix`) makes gamemode itself switch `power-profiles-daemon` to performance for the game's duration once launched under `gamemoderun` — which is exactly what this wrapper did by hand |
| `zink-run` wrapper — ported, then removed same day | Redundant: SteamTinkerLaunch (already in `gaming.nix` via `extraCompatPackages`) has a per-game custom-environment-variable feature that covers the same `MESA_LOADER_DRIVER_OVERRIDE=zink` override with per-game persistence and a GUI, without a separate system-wide binary |
| `topmem` declined | Needs `lua5_4` + `luaPackages.luv`; the ~200-line third-party script would have to be packaged/inlined whole — maintenance weight not justified next to existing `ananicy`/`scx` tooling; revisit if a real need comes up |
| `dlss-swapper`/`dlss-swapper-dll` declined | NVIDIA DLSS-only; omen15 is AMD (`hardware-amd.nix`) |
| `DefaultTimeoutStartSec`/`StopSec` 15s/10s reconfirmed declined | Already decided 2026-08-11 (risk of killing a legitimately slow-starting service); the ksv port didn't surface a new reason to revisit |
| `@audio` PAM `rtprio`/`nice` reconfirmed declined | Already decided 2026-08-11; `security.rtkit.enable` (already on) is the modern per-process equivalent |
| cachyos `30-zram.rules` inline `SYSCTL{vm.swappiness}="150"` reconfirmed declined | Already decided 2026-08-12 (continued); would fight the existing deliberate `180` sysctl |
| `amdgpu`/`radeon` `si_support`/`cik_support` reconfirmed declined | Already decided 2026-08-12; wrong GPU generation (targets 2012–2014 GCN 1.0/2.x) |
| journald `SystemMaxUse` 50M vs. kept 64M reconfirmed | Already decided 2026-08-11; pure disk-retention tradeoff, not security/perf |

### 2026-09-11 (continued: full 52-file vendored `cachyos` tree walked end-to-end, not just the `diff_sysctl.py`-covered rows — closes the gap the provenance table's "Full item-by-item sysctl comparison" row always had)

| Item | Tradeoff |
|---|---|
| `NetworkManager/conf.d/dns.conf` (`dns=systemd-resolved`) declined | Would hand DNS resolution to `systemd-resolved`, which is intentionally off here (`services.resolved.enable` stays at its default `false` — see 2026-08-11 review log) in favor of the existing `unbound` (DNSSEC-validating, RPZ blocklist) → `dnscrypt-proxy` (DoH/DNSCrypt) chain in `core.nix`. Porting this line blind would have silently broken that chain — worth recording explicitly rather than leaving it an unreviewed landmine |
| `usr/bin/sbctl-batch-sign` declined | Category is genuinely relevant here (omen15 dual-boots Windows via limine with `secureBoot.sbctl` — checked `hosts/omen15/omen15.nix`), but the mechanism is redundant: `boot.loader.limine.secureBoot.sbctl` already auto-signs every NixOS-managed boot file on each generation switch, and the script explicitly skips Microsoft/Windows-signed files (the only other thing under `/boot`) by design — nothing is left for it to catch |
| `usr/bin/paste-cachyos` + `usr/bin/cachyos-bugreport.sh` declined | Hardcoded to `paste.cachyos.org` (third-party upload, no auth) and to `pacman`/`cachyos-v3`/`v4`/`znver4` repo detection — not portable to NixOS, and an auto-upload-to-a-third-party-server tool cuts against this repo's `privacy.nix` posture |
| `usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf` declined | `systemd-timesyncd.service` doesn't even exist on this system (`systemctl is-enabled` → `not-found`) — `chrony` is the active NTP client, and its server list already includes `time.cloudflare.com` as an NTS (authenticated) source, stricter than upstream's plain NTP entry |
| `usr/lib/tmpfiles.d/coredump.conf` (`3d` retention) reconfirmed no-op | Byte-identical to secureblue's version already logged 2026-08-12 (continued) as a likely no-op — coredumps are triple-banned (`DumpCore=false` + ulimit `core=0` + `systemd.coredump.enable=false`), so nothing ever lands in that directory to expire |
| `usr/share/X11/xorg.conf.d/20-touchpad.conf` (libinput `Tapping=True`) + `usr/share/glib-2.0/schemas/…gnome.login-screen…` declined | Both are non-issues here: niri is Wayland-only (no Xorg input stack) and not GNOME. Tap-to-click, if wanted, is a niri KDL config concern in `dot_config/`, not this flake |
| `etc/debuginfod/cachyos.urls` declined | Points `gdb`/`coredumpctl` at CachyOS's debuginfod server, which only has symbols for Arch/CachyOS's own binary builds — useless against NixOS store paths (different build IDs entirely) |
| `usr/lib/modprobe.d/nvidia.conf` (`NVreg_InitializeSystemMemoryAllocations=0`, `NVreg_DynamicPowerManagement=0x02`) — no gap | Already present in `modules/hardware/nvidia.nix:91-92` (omen15 turns out to be an AMD-CPU + NVIDIA-dGPU hybrid laptop, not pure AMD — `hardware/nvidia.nix` is imported alongside `hardware-amd`) |

**Conclusion of this pass**: every file in the vendored `cachyos` snapshot (52
files) is now accounted for — ported, explicitly declined with a reason
above, or already logged in an earlier review. No outstanding gap remains
as of this date.

### 2026-09-11 (continued: madaidans-insecurities.github.io Linux Hardening Guide audited directly — upgrades row 24's prior indirect citation to a primary-source review)

Scope: `guides/linux-hardening.html` (actionable checklist), `linux.html`
(architecture critique), `encrypted-dns.html` (directly relevant — this repo
runs a real unbound + dnscrypt-proxy stack). The site's other 5 pages
(android, firefox-chromium, linux-phones, browser-tracking, messengers, vpns)
and its `security-privacy-advice.html` guide are about browser/VPN/messenger
choices, not NixOS system config — out of scope for this pass.

The guide is written for a from-scratch Gentoo/musl/no-systemd build, so a
large fraction of it (distro/init/libc selection, LibreSSL, rolling release,
tirdad, sdwdate, uninstalling NTP) doesn't transfer to a NixOS+glibc+systemd+
chrony system and isn't re-litigated below. The kernel/sysctl/PAM/USBGuard/
coredump/ASLR baseline **matches almost line-for-line** — `kptr_restrict=2`,
`dmesg_restrict=1`, `unprivileged_bpf_disabled=1`, `bpf_jit_harden=2`,
`kexec_load_disabled=1`, `dev.tty.ldisc_autoload=0`, `vm.unprivileged_userfaultfd=0`,
`fs.protected_{symlinks,hardlinks,fifos,regular}`, `vm.mmap_rnd_bits=32`,
`slab_nomerge`, `init_on_alloc=1`, `page_alloc.shuffle=1`, `oops=panic`,
`debugfs=off`, `vsyscall=none`, `random.trust_cpu=off`, ICMP/redirect/source-route
lockdown, `su.requireWheel=true`, `fs.suid_dumpable=0` + triple coredump ban,
root has no password hash on any deployed host (locked, matches the guide's
`passwd -l root` intent by construction) — all already ported, no new action.

**New findings — for the user to decide, nothing applied:**

| Item | What the guide says | Current state | Why it's flagged |
|---|---|---|---|
| **Full-disk encryption** | §21.1: FDE essential, `/boot` is the one thing it can't cover | `hosts/omen15/disko.nix` — plain btrfs on the NVMe root, no LUKS/dm-crypt layer anywhere in the repo (grepped, zero hits) | The single most consequential gap found. omen15 is a laptop that already dual-boots Windows and has Secure Boot live (`limine.secureBoot.sbctl`) — physical loss/theft exposes everything on disk in plaintext (browser profiles, downloaded files, shell history; sops-nix secrets are separately age-encrypted so those specifically are fine). Not attempted here — repartitioning a live root to add LUKS is a real, disruptive migration, explicitly left for the user to schedule |
| `module.sig_enforce=1` | §2.3: only load signed kernel modules | Not set anywhere | **Not a quick win** — Secure Boot here only signs the boot image (`limine.secureBoot.sbctl`), not individual `.ko` files; NixOS has no turnkey module-signing pipeline the way e.g. Fedora does. Enabling this blind would very likely fail to load `zenpower` (`hosts/omen15/omen15.nix:124-154`, an out-of-tree module built via `kernelPackages.zenpower`) and break boot. Needs its own investigation (does nixpkgs support signing out-of-tree modules against the kernel's own key at all?) before it's actionable |
| `/home` mount `noexec` | §17: `noexec` on `/home` | `disko.nix` already sets `nosuid,nodev` on the `/home`/`/nix`/`/persistent` subvolumes — `noexec` specifically is the one flag missing | The guide itself concedes "`noexec` can be bypassed via shell scripts"; also would likely break AppImages/user-installed binaries under `~/.local/bin`. Real option, not an oversight — worth an explicit yes/no rather than silence |
| Hostname/username genericization | §10.1: generic hostname+username, avoid unique identifiers | `networking.hostName` is `omen15`/`oci`/`rpi4-switch`/`rpi4` per host; `mainUser = "hydroakri"` everywhere | Sits oddly next to how aggressive `privacy.nix` otherwise is (MAC randomization, IPv6 privacy addresses, kloak). In fairness the exposure is narrower than it sounds — hostname mostly leaks over local/DHCP broadcast, not to remote web trackers, which is `privacy.nix`'s actual threat model — but it's an inconsistency worth naming rather than leaving unexamined |
| Encrypted Client Hello (ECH) | Not asked for by `linux-hardening.html`, but directly implied by `encrypted-dns.html`'s own conclusion (see below) | No ECH-related key in `privacy.nix`'s Brave `castration.json` policy | `encrypted-dns.html` argues DNS encryption alone doesn't hide anything because SNI leaks the hostname in plaintext during the TLS handshake — ECH is the actual fix for that specific leak, and it's genuinely new ground this repo hasn't touched. Whether Brave's policy schema exposes a working ECH toggle (`EncryptedClientHelloEnabled2` or similar Chromium policy key) needs checking before deciding |
| `dnscrypt-proxy` `require_dnssec=false` | Implied by encrypted-DNS best practice generally | `core.nix` `services.dnscrypt-proxy.settings.require_dnssec=false` | Low actual risk: `unbound` (the resolver the whole system actually talks to) does its own independent DNSSEC validation regardless of what dnscrypt-proxy claims about upstream responses — this flag only affects whether dnscrypt-proxy itself refuses to relay a non-DNSSEC answer, not whether validation happens. Flagged for an explicit decision rather than left as an unexamined "false" |
| `hosts/rpi-image/rpi-image.nix`: `users.users.root.initialPassword = "root"` | §8.3: lock root account | Set only on this one host, not on any deployed router/desktop | Worth a one-line confirmation this is intentional (SD-card image first-boot/installer convenience, not a persistently deployed host) rather than a leftover — it reads alarming out of context next to everything else in this table |

**Needs nuance, not a blind port (already-considered or context-dependent):**

| Item | Guide's ask | Current state | Reasoning |
|---|---|---|---|
| `kernel.perf_event_paranoid` | `3` (CAP_PERFMON only) | `2` on desktop (`security.nix:168`, explicit comment: root-only `perf` via `doas`, server overrides to `3` at `mkOverride 900`) | Already a deliberate desktop/server split for dev-tooling access, not an oversight — reconfirmed against the direct source, no change |
| `vm.swappiness` | `1` — guide's stated reason is "avoid sensitive data on disk via swap" | `180` (`performance.nix`, tied to zram sizing) | The guide's threat model is disk-backed swap; this repo's swap is 100% `zram` (compressed RAM via `services.zram-generator`, `zswap.enabled=0`) — nothing swapped ever touches persistent disk, so the specific risk the guide is defending against doesn't apply here. Would need revisiting only if disk-backed swap were ever added |
| `kernel.sysrq` | `4` (SAK only) | `246` (`core.nix`, "curated safe subset", already reconfirmed once 2026-08-12 against Kicksecure/secureblue's blunt on/off) | Madaidan's `4` is a *third* independent source landing on a narrower value than the repo's current `246` — the previous decision only weighed two all-or-nothing alternatives against the curated subset. Worth an actual second look at which SysRq keys `246` enables beyond SAK, not a blind reconfirm this time |
| `kernel.yama.ptrace_scope` | `2` (admin-only, no exceptions) | `1` (kept 2026-08-11: "GrapheneOS's `2` untested, not worth the risk"; `3` broke Steam) | Madaidan explicitly wanting `2` is the same value that decision already flagged as untested-but-plausible — doesn't change the calculus, still not worth testing on a daily driver without a throwaway host to verify on first |
| `net.ipv4.tcp_sack`/`tcp_dsack`/`tcp_fack` | All `0` | `sack=1` (perf override, "CVEs patched since 2019"), `dsack=0`/`fack=0` (hardened) | Reconfirmed against the direct source: the split was already deliberate, not an oversight that only 2 of 3 got hardened |
| AppArmor "enabled but mostly unconfined" (`linux.html`'s explicit critique of exactly this pattern) | Full system-wide MAC policy, not just the framework enabled | `security.apparmor.enable=true` + nixpkgs' bundled profiles only (provenance table row 41) | The critique is valid and not new information, but authoring a full custom policy is its own substantial project, not a config tweak — explicitly accepted as a scope limit rather than silently ignored. `desktop.nix`'s `security.nixpak` bubblewrap sandboxing on the actual highest-risk unconfined processes (brave/mullvad-browser/tor-browser) is a real, if partial, mitigation for the same underlying concern |
| Sandboxing tool choice | Bubblewrap over Firejail explicitly ("Firejail: unsafe sandbox implementation") | `desktop.nix` `security.nixpak` — bubblewrap-based, no Firejail anywhere in the repo | Already matches; worth citing explicitly since `security.nix`/`privacy.nix` alone don't show this — it lives in `desktop.nix` |
| Hardened memory allocator | `hardened_malloc`, `VARIANT=light` to minimize breakage | `environment.memoryAllocator.provider = "graphene-hardened-light"` | Already matches almost exactly — GrapheneOS's hardened_malloc, light variant |

**Declined / not applicable:**

| Item | Reason |
|---|---|
| musl / Gentoo / LibreSSL / non-systemd / rolling-release base distro | Base-platform-level advice; re-litigating NixOS+glibc+systemd isn't in scope for a settings audit |
| Uninstall NTP clients, use sdwdate instead | `chrony` with NTS (`core.nix`) already addresses the guide's actual complaint — "NTP is unauthenticated" — via authenticated time sync, without going as far as the guide's Tor-project-specific sdwdate suggestion |
| `tirdad` (random TCP ISNs) | Whonix/Tor-project-specific kernel module, no nixpkgs package, no matching threat model here |
| `encrypted-dns.html`'s actual conclusion | Not a settings gap — the article's point is that DNS-layer privacy tooling (however elaborate) doesn't hide site identity because SNI/OCSP/source-IP still leak it, and recommends VPN/Tor instead of more DNS tuning. There's nothing to port from it; noted above only insofar as it directly motivates checking ECH support |

## Quarterly review process (Plan A: manual)

Run this once per quarter, on the last weekend of the quarter (worth a
calendar reminder):

1. **Fetch upstream** — run `docs/upstream-vendor/refresh.sh` (covers
   CachyOS/Kicksecure/secureblue/Bazzite/nix-mineral/Pop!_OS/GrapheneOS-infra/OpenBSD/Tails
   automatically); manually shallow-clone only what's still outside that
   set: `Kicksecure/hardened-kernel` (Kconfig, not pursued — see provenance
   table)
2. **Diff**: `docs/upstream-vendor/diff_sysctl.py` and `diff_misc.py` for
   the automated sources; manually review anything without a parser (udev
   rules, AppArmor, systemd `.service.d`/`.slice.d` — see coverage map in
   `docs/upstream-vendor/README.md`) against the previous review's notes
3. **Update this table**: fill in the "Last reviewed" date and the
   upstream version/commit; tag any newly appeared settings per the status
   legend
4. **Experiment with each candidate change individually**: roll out from
   lowest-risk host first, **oci → rpi → omen15**; run
   `nixos-rebuild build` before switching on each; record every
   conclusion (kept/rejected) in `known-breaking-settings.md`
5. **Merge**: only merge settings that have actually been tested; update
   README "Reference Sources" if any new source was added
