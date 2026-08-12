# Known Breaking Settings

This log records the **actual failures hit** while porting/experimenting with
these upstream kernel parameters, sysctls, and udev rules — symptoms, root
cause, final disposition, and how it was verified. Two uses:

1. A quick-reference sheet for hitting a similar problem again in the future
2. A **checklist** to run before pulling in anything new from upstream —
   check this table first so a known landmine doesn't get re-imported

Status legend: `reverted` (tried, rejected) | `kept` (kept, with a
workaround) | `disabled` (not enabled, waiting on upstream fix) |
`untested` (theoretical risk only)

## A. Boot/system-level risk (most severe)

| Setting | Symptom | Root cause | Disposition | Source | Verification |
|---|---|---|---|---|---|
| `oops=panic` + `kernel.panic=-1` | Any kernel oops triggers an immediate reboot; an early-boot oops can turn into an infinite reboot loop | Standard KSPP combination, but risky in a loop when paired with a new kernel/config; `-1` means "reboot immediately" | Kept (standard KSPP) | `security.nix` / hardened.nix | Must pass the CI build matrix before going on real hardware; roll it on oci first and watch reboot stability |
| LKRG (lkrg-1.0.0) | Module fails to load / incompatible | lkrg-1.0.0 is incompatible with kernel 7.x (`sockaddr_unsized` API change) | Disabled, waiting on upstream support | Kicksecure | Re-verify after every major kernel bump |
| tirdad | Fails to load | Requires `CONFIG_LIVEPATCH=y`, and depends on an upstream fix | Disabled | Kicksecure | Same as above |
| `pcie_aspm=force` + `pcie_port_pm=force` | Potential idle-suspend/device-wake failures | Forcing ASPM conflicts with some devices' power management | Kept, but flagged in comments: "turn these two off first if something breaks" | CachyOS | Suspend/wake cycle testing (`systemctl suspend` → wake) |
| amdgpu PSR (`amdgpu.dcfeaturemask=0x8`) | Display freeze | amdgpu DMCUB firmware on Cezanne crashes when PSR is enabled | Reverted (kept as a comment) | CachyOS | Check whether the display freezes after sitting idle |
| `kernel.kexec_load_disabled=1` | `systemctl kexec` fast reboot and kdump stop working | By design (prevents loading a new kernel without passing BIOS POST) | Kept (known tradeoff) | Kicksecure | None |
| `amd_iommu=force_isolation` | Kernel panic on boot (omen15, gen 106); no journal entries at all — panicked before `systemd-journald` started | Forces per-device IOMMU group isolation; likely PCIe ACS not cleanly supported at every hop on this board's topology. A known boot-hang report on kernel 6.13 was noted before adding this, then dismissed as probably fixed on this repo's 7.1.6 kernel without actually testing that assumption | Reverted, removed from `boot.kernelParams` | nix-mineral / Kicksecure | Confirmed sole cause: gen 107 (105 + only `iommu.strict=1` + `lockdown=integrity`, no `amd_iommu`) booted clean |
| `random.trust_cpu=0` + `random.trust_bootloader=0` | Noticeably slower boot when entropy is low at startup | Doesn't trust CPU RDRAND/firmware entropy, waits for real entropy sources | Kept | Kicksecure | Compare boot times |

## B. Functionality-breaking (doesn't stop boot, but kills some software)

| Setting | Symptom | Root cause | Disposition | Source | Verification |
|---|---|---|---|---|---|
| `kernel.yama.ptrace_scope=3` | Some Steam games stop working | Fully disables ptrace; anti-cheat/debuggers depend on it | Reverted to 1 (only disallow ptrace between unprivileged users) | Kicksecure/nix-mineral | Already noted in code comments |
| `kernel.io_uring_disabled` set to 2 on desktop | A batch of userspace programs (including some games/concurrency libraries) throw io_uring errors | io_uring is a mainstream async I/O interface; fully disabling it breaks compatibility | Desktop keeps it at 1; only the server strict-mode block sets 2 | Kicksecure | Run a normal round of desktop apps |
| `kernel.perf_event_paranoid=3` | perf/sampling tools completely unusable | By design | Desktop uses 2 (root-usable), server uses 3 | Kicksecure | Discovered when profiling is needed |
| `fs.binfmt_misc.status=0` (server block only) | Wine / binfmt-runner stops working | Disabling binfmt_misc is a server-only hardening item | Desktop hosts unaffected, kept | Kicksecure | Not touched on desktop |
| `vm.unprivileged_userfaultfd=0` | A handful of high-performance VM features stop working | Disables unprivileged userfaultfd | Kept (generally no impact on desktop, noted in comments) | Kicksecure | None |
| `net.ipv4.icmp_echo_ignore_all=1` | Ping doesn't work (looks like "host down" from outside) | By design (anti-fingerprinting/amplification); use TCP ping instead | Kept | Kicksecure | `tcping`/SSH connectivity |
| `net.ipv4.conf.all.rp_filter=1` (strict mode) | Transparent proxy (dae / sing-box TUN) traffic gets dropped | Reverse path filtering too strict for proxy setups | Kept — `proxy.nix` auto-overrides to 2 when it detects a proxy | Kicksecure | Egress traffic test with the proxy on |
| `net.ipv4.tcp_timestamps=0` | Performance drop (high-bandwidth long-lived connections) | Disabling timestamps is a security item, costs performance | Kept — `performance.nix` deliberately overrides back to 1 (priority 900 < baseline 950) | Kicksecure | Bandwidth test comparison |
| iwd WiFi backend | omen15 wireless unstable/drops | Realtek NIC driver compatibility issue with iwd | omen15 overrides back to `wpa_supplicant` (module default is still iwd) | Field-tested | Long-running soak test |
| `DebianBanner=false` in `services.openssh.settings` | Rebuild fails, sshd config test rejects an unrecognized directive | `DebianBanner` is a Debian/Ubuntu-only sshd_config patch, not present in nixpkgs' vanilla upstream OpenSSH build | Reverted (manually removed); `PrintMotd=false` kept, covers the same banner-suppression intent | Kicksecure | `nixos-rebuild build` fails config validation |
| `iommu=strict` kernel param | No boot failure, but never did what it looked like it did | Not a real kernel parameter — the generic IOMMU layer's actual flag is dot-namespaced `iommu.strict=1`; `iommu=strict` was silently accepted as an unrecognized value and had no effect | Fixed — replaced with `iommu.strict=1` | nix-mineral (`strict-iommu.nix` had the correct form) | Gen 107: `journalctl -k` shows "strict mode (set via kernel command line)" |
| `lockdown=confidentiality` kernel param | No boot failure, but never did anything at all | Different failure class from `iommu=strict` — the parameter name and value are both valid, but this repo's cachyos-bore-lto kernel build never compiled `CONFIG_SECURITY_LOCKDOWN_LSM` in the first place (confirmed via `/proc/config.gz`: `# CONFIG_SECURITY_LOCKDOWN_LSM is not set`), so the whole LSM the parameter configures doesn't exist in the running kernel. Separately, NixOS's own `security.lsm`/`security.apparmor` modules also emit an explicit `lsm=` boot param (`landlock,yama,apparmor,bpf`) that never included lockdown anyway — even a compiled-in lockdown LSM wouldn't activate without also being added there. `/sys/kernel/security/lockdown` doesn't exist, confirming the LSM never loaded | Kept, value corrected to `lockdown=integrity` (was `confidentiality`) — still fully inert, but the right value to already have in place if `CONFIG_SECURITY_LOCKDOWN_LSM` is ever added via a kernel Kconfig patch. Not pursued now — same "not worth the Kconfig maintenance burden" call already made 2026-08-11 for kernel hardening generally. Individual settings already elsewhere in `security.nix` (`kexec_load_disabled=1`, `debugfs=off`, `nohibernate`) cover some of what lockdown would have provided; things it uniquely gates (raw `/dev/mem`/`/proc/kcore`, MSR writes, ACPI table overrides) currently have no substitute | KSPP / this repo's own `security.nix` | `cat /sys/kernel/security/lockdown` — file must exist for the LSM to be active at all; `/proc/config.gz` for the Kconfig symbol |
| `cfi=kcfi` kernel param | No boot failure, silently inert | `# CONFIG_CFI is not set` in `/proc/config.gz` — Control Flow Integrity itself isn't compiled in, despite the kernel being Clang-built (`CONFIG_CC_IS_CLANG=y`, which is a prerequisite but not sufficient on its own) | Kept as-is, harmless dead weight — not pursued (same Kconfig-maintenance-cost reasoning) | Kicksecure / KSPP | `zgrep CONFIG_CFI /proc/config.gz` |
| `extra_latent_entropy` kernel param | No boot failure, silently inert | No `CONFIG_LATENT_ENTROPY`/`CONFIG_GCC_PLUGIN_LATENT_ENTROPY` symbol anywhere in `/proc/config.gz`. Doubly inapplicable: latent_entropy has traditionally been a GCC-plugin feature, and this kernel is Clang-built (`CONFIG_CC_IS_CLANG=y`) — the GCC plugin ABI doesn't apply to a Clang toolchain at all | Kept as-is, harmless dead weight — not pursued | KSPP / madaidans-insecurities | `zgrep -i LATENT_ENTROPY /proc/config.gz` |
| `proc_mem.force_override=ptrace` kernel param | Not dead — a real, working override, but in the *less-strict* direction | `CONFIG_PROC_MEM_ALWAYS_FORCE=y` is this kernel's compiled-in default (the strictest `/proc/pid/mem` access mode); the boot param actively downgrades that to the `ptrace`-gated mode at runtime. Confirmed as a functioning runtime override (boot params for this feature take precedence over the Kconfig default), not a Kconfig gap | Kept at `ptrace` deliberately — known compatibility consideration (some tooling needs `/proc/pid/mem` access outside a ptrace relationship that the stricter `always` mode would block) | Kicksecure / KSPP | N/A — behavior is by design, not a bug; re-verify the compatibility need still exists before ever tightening to `always` |
| hardened malloc (graphene-hardened-light) | Some games/perf-sensitive apps drop frames | Hardened allocator has overhead | Kept; scudo (balanced)/mimalloc (performance) noted as alternatives in comments | hardened.nix | Game frame-rate comparison |
| `cfi=kcfi` | Overall performance loss | Kernel CFI trades complexity for security | Kept (noted as "slightly performance loss") | KSPP | None |
| `slub_debug=FZP` | 10-20% performance overhead | Allocator debugging (integrity + redzoning + poisoning) | Disabled, only turned on temporarily during dev debugging | Field-tested (noted in comments) | None |
| earlyoom false kills | Games/Wine processes killed by OOM | earlyoom threshold too aggressive | Kept — `--avoid (exe|steam|wine|gamescope|mangohud|proton)` | Field-tested | Launch a game under heavy memory load |
| kloak running persistently | niri global shortcuts, fcitx5 IME stop working | kloak exclusively grabs the real keyboard (by design) | Kept — not `wantedBy`, manually `doas systemctl start/stop kloak` | Whonix | Manual start/stop verification |
| `vm.swappiness` high value (180/150) | A machine without zram over-uses disk swap | High swappiness is tuned for zram-compressed memory | Kept — tied to `zram-generator`; disabling zram requires reverting this too | CachyOS | Check whether `zramctl` is running |
| zswap and zram coexisting | Memory pressure behaves erratically | The two compressed-swap stacks fight each other | Fixed — `zswap.enabled=0` + zswap disabled after zram0 init | CachyOS | `zramctl`/`/sys/module/zswap/parameters/enabled` |

## C. Upstream modules fighting the kernel version

| Symptom | Root cause | Disposition |
|---|---|---|
| Module `meta.broken`: lags behind the pinned kernel version | Upstream modules (e.g. LKRG, tirdad) lag behind new kernel APIs | Check whether upstream supports the target kernel before upgrading (see comment in `hosts/isolive/isolive.nix`); CI blocks a failing build |

## Experimental discipline (how to avoid "machine won't boot")

1. Default rollout order: **oci → rpi → omen15** (a broken server is cheapest
   to lose; the main laptop goes last)
2. On a machine at the console: NixOS has generation rollback as a safety
   net (`nixos-rebuild list-generations` + pick an older generation from the
   boot menu), but **only the generation that drops the broken parameter can
   actually save you** — so change one setting group at a time
3. Remote machines (oci/rpi): run `nixos-rebuild build` (no activate) first,
   confirm the build passes before switching; when changing boot-time
   settings like kernel params, have a rescue path ready (Oracle Cloud's
   VNC/console, the rpi's serial console)
4. Run new settings through `nix flake check` + the CI build matrix before
   putting them on real hardware — they won't boot the system, but they
   catch typos/type errors
