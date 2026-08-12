# Upstream Vendor + Diff

Vendors upstream distro/project settings files locally and diffs them
against `flake/modules/features/*.nix`, instead of hand-diffing during the
quarterly review. Covers every source under `docs/upstream-settings.md`
that's a flat `key = value` table (CachyOS, Kicksecure, secureblue,
Bazzite, nix-mineral), plus non-flat sources reviewed manually against the
vendored snapshot (Tails' `config/` — AppArmor hardening). Qubes/Pop!_OS's
kernel source and Kicksecure's `hardened-kernel` are architecture
references, not settings tables — those stay on the manual clone+diff
process described in `docs/upstream-settings.md`.

**Only `refresh.sh`, `diff_sysctl.py`, `diff_misc.py`, and this README are
committed.** Vendored `<source>/` subdirectories are gitignored
(`docs/upstream-vendor/*/`) — regenerable via `./refresh.sh`, never
committed (would otherwise mean carrying ~1MB of third-party
GPL/AGPL/Apache text).

## Vendoring

`refresh.sh` vendors every file in each source's clone (minus `.git`,
minus files over 256K), regardless of location — no per-source path list.
The diff scripts locate their target directories by name
(`rglob("sysctl.d")`, `rglob("modprobe.d")`, etc.), so a source adding a
new config category anywhere just shows up on the next refresh with no
code change needed. Extra vendored noise (source code, CI config, GUI
overrides) is cheap: ~13MB / 1533 files across five sources; the size cap
keeps out multi-MB binary blobs (wallpapers/firmware).

## Three mechanisms

1. **`diff_sysctl.py`** — static `key = value` diff: this repo's sysctl vs
   vendored CachyOS/Kicksecure/secureblue/Bazzite `sysctl.d` files +
   nix-mineral's Nix source (parsed with the same key regex).
2. **Kernel Kconfig — not pursued.** Distro `.config`/annotation files
   compared against a different kernel version is mostly version-drift
   noise, not signal. See "Kernel Kconfig hardening" in
   `docs/upstream-settings.md`.
3. **`diff_misc.py`** — every other flat, comparable config category found
   in at least one vendored source. See Coverage map below.
4. **udev rules** — vendored for manual `diff -ru`, not parsed (rule
   syntax isn't a settings table).
5. **systemd `*.service.d`/`*.slice.d` overrides** — not parsed (no automated
   diff, `ini`-shaped but too varied to key-match generically). Manual
   review only; found during the 2026-08-12 sweep, added to the coverage
   map below. Re-check this bucket on future refreshes — it wasn't part of
   the original coverage-map audit and could drift again.

## Coverage map

Every distinct config category found across all five vendored sources
(audited via `find docs/upstream-vendor -type d -name "*.d"` after a fresh
refresh), sorted into three buckets. Re-run that command after any refresh
— an unlisted bucket-1-shaped category is a real gap.

**1. Diffed automatically** (match/DIFFERS/not-ported against a real Nix declaration):

| Category | Compared against | Script |
|---|---|---|
| `sysctl.d` | `boot.kernel.sysctl` | `diff_sysctl.py` |
| nix-mineral `settings/`/`extras/` (Nix source) | same, parsed as Nix | `diff_sysctl.py` |
| `modules-load.d` | `boot.kernelModules` / `boot.initrd.kernelModules` | `diff_misc.py` |
| `modprobe.d` | `boot.extraModprobeConfig` + `boot.blacklistedKernelModules` | `diff_misc.py` |
| `ssh/sshd_config.d` | `services.openssh.settings` | `diff_misc.py` |
| `ssh/ssh_config.d` (client) | `programs.ssh.extraConfig` | `diff_misc.py` |
| `systemd/journald.conf.d` | `services.journald.extraConfig` | `diff_misc.py` |
| `environment.d` | `environment.variables` / `environment.sessionVariables` | `diff_misc.py` |
| `usbguard-daemon.conf` | `services.usbguard.*` | `diff_misc.py` |

**2. Vendored and listed, report-only** (real settings-table format, but
this repo declares nothing in that option namespace to compare against):

| Category | Would compare against, if declared |
|---|---|
| `security/limits.d` | `security.pam.loginLimits` |
| `tmpfiles.d` | `systemd.tmpfiles.rules` |
| `systemd/coredump.conf.d`, `resolved.conf.d`, `system.conf.d`, `networkd.conf.d`, `pstore.conf.d`, `timesyncd.conf.d`, `user.conf.d` | none of these have a raw-string/settings escape hatch this repo currently uses |
| `NetworkManager/conf.d` | `networking.networkmanager.*` sets high-level options, not raw conf.d keys — no direct mapping exists yet |
| `openbsd/etc/unbound.conf` | `services.unbound.settings.server` — real key overlap (`hide-identity`, `aggressive-nsec`, `tls-cert-bundle`, etc.) but no parser: unbound.conf's `section:`-nested format isn't a flat `key = value` list like `sysctl.d` |
| `*/etc/systemd/system/*.service.d`, `*.slice.d` (grapheneos-infra, Kicksecure) | `systemd.services.<name>.serviceConfig` / `systemd.slices.<name>.sliceConfig` — real overlap (found `unbound.service.d`, `chronyd.service.d`, `sshd.service.d`, `rescue.service.d`, `-.slice.d`, `system.slice.d`, `fstrim.service.d`/`.timer.d`, `systemd-boot-update.service.d`) but no parser, reviewed manually 2026-08-12 |

**3. Deliberately not diffed** (format or scope reasons):

| Category | Why |
|---|---|
| `udev/rules.d` | rule syntax, not key=value |
| `apparmor.d`, `*.te`/`*.if`/`*.fc` (SELinux modules) | profile/policy language, not a settings table |
| `polkit-1/rules.d` | JS procedural rules |
| `dconf/db/distro.d`, `gschema-overrides/*.override` | GNOME dconf — this host runs niri, not GNOME |
| `sudoers.d` | this repo uses `doas`, not `sudo` |
| `sysusers.d` | declares distro-specific service accounts, not a hardening/tuning setting |
| `hwdb.d` | modalias match-pattern syntax, not key=value |
| `unbound/conf.d` | different format, zero key overlap — this repo's `services.unbound.settings` configures `rpz`/`forward-zone`, upstream's files only set daemon hardening flags |
| `containers/registries.d` | bootc/ostree image signing — NixOS doesn't use this update mechanism |
| `hide-hardware-info.d`, `permission-hardener.d`, `usbguard/IPCAccessControl.d`, `usbguard/rules.d` | config for Kicksecure-specific tools not present on NixOS |
| `apt.conf.d`, `yum.repos.d`, `dnf`, `rpm-ostreed.conf` + `*.d` | package-manager config — NixOS doesn't use apt/dnf/rpm-ostree |
| `grub.d`, `dracut.conf.d`, `dracut/modules.d`, `kernel/postinst.d`, `bootc/kargs.d` | kernel/boot infrastructure, Kconfig-adjacent, deliberately not pursued |
| `sway/config.d`, `sddm.conf.d`, `plasma-*.service.d`, `org.gnome.Shell@user.service.d`, wireplumber/pipewire hardware-profile `conf.d` | desktop-environment or hardware-variant specific — this host runs niri on an AMD desktop |
| `profile.d`, `issue.d` | shell scripts / login banner text, not declarative settings |
| per-service `*.service.d`/`*.socket.d`/`*.timer.d` overrides (avahi, rpm-ostreed-automatic, rtkit, haveged, usbguard, mcelog, beesd@, user@) | none of these services have any override in this repo |

Known bug, fixed: Kicksecure stacks a second packaging suffix on some
files (`usbguard-daemon.conf.security-misc#security-misc-shared`);
`refresh.sh` now strips an exact trailing `.security-misc` in addition to
the `#...` part (literal-suffix strip, doesn't clip `30_security-misc.conf`).

## Layout

All of the below is produced by `./refresh.sh` into gitignored
`<source>/` subdirectories — it exists on disk after you run it, not in
git. `<source>/` mirrors the upstream repo's full directory structure, so
what's actually in there varies per source; these are the parts the diff
scripts look at:

- `<source>/SOURCE.md` — repo URL, branch, commit, fetch date, license for that vendor snapshot
- `<source>/LICENSE.upstream` — that source's own license text, vendored verbatim
- `<source>/**/sysctl.d/`, `udev/rules.d/`, `modprobe.d/`, `modules-load.d/`, `journald.conf.d/`, `security/limits.d/`, `ssh/sshd_config.d/`, `ssh/ssh_config.d/` — found and diffed by name, at whatever depth that source nests them
- `nix-mineral/settings/`, `nix-mineral/extras/` — parsed as Nix source by `diff_sysctl.py`
- everything else vendored (packaging scripts, docs, CI config, the odd GUI settings override) isn't touched by any parser — there for `grep`/manual review, not automated

## Licensing

This repo's top-level `LICENSE` is MIT. The files `./refresh.sh` produces
locally under `docs/upstream-vendor/<source>/` are not — each keeps
whatever license that upstream project chose:

| Source | License |
|---|---|
| cachyos | GPL-3.0 |
| kicksecure | AGPL-3.0-or-later |
| secureblue | Apache-2.0 |
| bazzite | Apache-2.0 |
| nix-mineral | GPL-3.0 |
| pop-default-settings | GPL-3.0 |
| grapheneos-infra | MIT |
| openbsd | BSD-2-Clause/ISC (per-file; no repo-wide `LICENSE`) |
| tails | GPL-3.0-or-later |

Vendoring doesn't put this repo's own MIT code under GPL: settings values
(`vm.swappiness = 180`) are facts/parameters, not copyrightable
expression, and the Nix module code expressing them is original and never
compiled, linked, or built together with the vendored files — they're
inert reference text read by a Python script and by humans, not part of
the NixOS closure. Since the vendored tree is gitignored (never
committed, never pushed), there's no redistribution event happening
through this repo either. Not legal advice — get a real read if this ever
matters commercially (e.g. distributing a built image containing these
files).

## Usage

```bash
# re-clone every source and refresh the vendored files + SOURCE.md
./refresh.sh

# diff sysctl keys declared in flake/modules/features/*.nix against every
# vendored source (cachyos, kicksecure, secureblue, bazzite, nix-mineral)
./diff_sysctl.py

# diff modules-load.d / modprobe.d / sshd_config.d / limits.d / etc.
./diff_misc.py
```

## Known limitations

- **Architecture-conditional values look like a single value**:
  `diff_sysctl.py` scans line by line and takes the last literal
  assignment of a key in file order — it doesn't understand
  `lib.optionalAttrs pkgs.stdenv.hostPlatform.isX86_64 { ... }` branches.
  Treat any DIFFERS on a key that might plausibly be architecture- or
  role-conditional as "go check the source," not as ground truth.
- **Glob vs explicit key false positives**: the sysctl diff matches keys
  as literal strings. Some sources use the glob form
  (`net.ipv4.conf.*.rp_filter`) where this repo sets `all`/`default`
  variants separately, or vice versa — functionally equivalent, but shows
  up as a false "not ported". Treat the "not ported" list as candidates to
  eyeball, not a ground-truth gap report.
- **Hardware/flavor variants from the same source can collide**: a source
  shipping multiple device profiles (e.g. Bazzite's `deck` vs `desktop`)
  can both contribute a same-named key; whichever file sorts last wins,
  with no "pick the relevant variant" logic. Treat any single value shown
  as "the vendored value" with the same skepticism as the rest of this
  tool. Confirmed hardware-variant false positives (2026-08-12): Bazzite's
  `deck/shared` `logind.conf.d`, `hid_nintendo`/`hid_playstation`
  modules-load, and handheld-specific `pipewire.conf.d` hardware profiles
  (Legion Go, GPD Win) — none apply to a desktop/server fleet.
- **`diff_sysctl.py` only scans `flake/modules/features/*.nix`**: sysctl
  set in `desktop.nix`, `server.nix`, or any other top-level module under
  `flake/modules/` (outside `features/`) won't be seen and will
  false-flag as "not ported". Confirmed case: `kernel.printk="3 3 3 3"`
  is set in `desktop.nix`, not `features/`, and showed up as a false gap
  in the 2026-08-12 sweep.
