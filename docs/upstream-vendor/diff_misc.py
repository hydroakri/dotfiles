#!/usr/bin/env python3
"""Diff the non-sysctl flat config categories that exist in at least one
vendored source: modules-load.d, modprobe.d, ssh/sshd_config.d,
ssh/ssh_config.d, security/limits.d, systemd */conf.d + NetworkManager
conf.d (INI), and tmpfiles.d. Kernel-build config (Kconfig, kernelParams,
dracut, grub.d) is deliberately out of scope entirely — see
docs/upstream-settings.md's "Kernel Kconfig" row: acting on a Kconfig
finding means maintaining kernel patches/build overrides, not a one-line
Nix change, and this repo already builds its own CachyOS kernel rather than
any of these distros' kernel, so it's not worth automating at any level.

Every category that has a real counterpart in this repo's
flake/modules/features/*.nix gets a matched (match/DIFFERS/not-ported)
comparison. Categories that exist upstream but have no counterpart here at
all are still listed — report-only, like security/limits.d already was —
rather than silently left out, so "we checked and found nothing to compare
against" stays distinguishable from "we never looked."
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
VENDOR_DIR = Path(__file__).resolve().parent
FEATURES_DIR = REPO_ROOT / "flake" / "modules" / "features"

ALL_NIX_TEXT = "\n".join(
    f"### {p.relative_to(REPO_ROOT)}\n{p.read_text()}"
    for p in sorted(FEATURES_DIR.rglob("*.nix"))
)


def extract_nix_list(option: str) -> set[str]:
    """Union of all `option = [ ... ];` occurrences (NixOS concatenates
    list-typed options across files by default, so union approximates the
    merged value)."""
    items: set[str] = set()
    for m in re.finditer(re.escape(option) + r"\s*=\s*\[(.*?)\]\s*;", ALL_NIX_TEXT, re.S):
        items.update(re.findall(r'"([^"]+)"', m.group(1)))
    return items


def extract_nix_string(option: str, anchor: str | None = None) -> str | None:
    """All `option = [wrapper] ''...'';` / `= [wrapper] "...";` occurrences,
    concatenated — this repo's `boot.extraModprobeConfig` is a `types.lines`
    option NixOS itself concatenates across every file that declares it
    (powersave.nix's iwlwifi line, security.nix's nf_conntrack line, etc.);
    matching only the first occurrence would silently drop every
    declaration after the first-encountered file. Some options are declared
    flat (`boot.extraModprobeConfig = ''...'';`) and some are nested
    (`programs.ssh = { extraConfig = ''...''; };` — `programs.ssh.extraConfig`
    never appears as a literal dotted string there). Pass `anchor` for the
    nested case, same idea as `extract_nix_block`: find `anchor` first, then
    search only from there (nested options are assumed single-occurrence)."""
    text = ALL_NIX_TEXT
    key = option
    if anchor is not None:
        idx = ALL_NIX_TEXT.find(anchor)
        if idx == -1:
            return None
        text = ALL_NIX_TEXT[idx:]
        key = option.rsplit(".", 1)[-1]
    parts = [
        m.group(1)
        for m in re.finditer(re.escape(key) + r"\s*=\s*(?:lib\.mk\w+\s+)?''(.*?)''\s*;", text, re.S)
    ]
    parts += [
        m.group(1)
        for m in re.finditer(re.escape(key) + r'\s*=\s*(?:lib\.mk\w+\s+)?"(.*?)"\s*;', text, re.S)
    ]
    return "\n".join(parts) if parts else None


def extract_nix_block(anchor: str, block_key: str) -> dict[str, str]:
    """`block_key = { Key = value; ... };` with bare (unquoted) keys, e.g.
    `settings` nested inside `services.openssh = { settings = {...}; };`.
    `services.openssh.settings` never appears as a literal dotted string in
    the source — Nix nests it — so this locates `anchor` first, then finds
    the nearest `block_key = { ... };` after it. Single occurrence assumed
    (this repo declares it once). Handles string/bool/int values on a
    single line, and `[ "a" "b" ]` lists spanning multiple lines (rendered
    as a comma-joined string, matching how NixOS serializes list-typed
    settings into the actual config file)."""
    result: dict[str, str] = {}
    idx = ALL_NIX_TEXT.find(anchor)
    if idx == -1:
        return result
    m = re.search(re.escape(block_key) + r"\s*=\s*\{(.*?)\n\s*\};", ALL_NIX_TEXT[idx:], re.S)
    if not m:
        return result
    block_text = m.group(1)
    # Multi-line lists first: `Key = lib.mkDefault [ "a" "b" ];` (list body
    # may span lines, so this runs on the whole block, not per-line).
    for lm in re.finditer(
        r'([A-Za-z][A-Za-z0-9]*)\s*=\s*(?:lib\.mk\w+\s+)?\[(.*?)\]\s*;', block_text, re.S
    ):
        items = re.findall(r'"([^"]+)"', lm.group(2))
        result[lm.group(1)] = ",".join(items)
    for line in block_text.splitlines():
        km = re.match(
            r'\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*(?:lib\.mk\w+\s+)?("[^"]*"|true|false|-?\d+)\s*;',
            line,
        )
        if km:
            v = km.group(2)
            if v.startswith('"'):
                v = v[1:-1]
            elif v in ("true", "false"):
                v = "yes" if v == "true" else "no"
            result[km.group(1)] = v
    return result


def parse_modules_load(dirs: list[Path]) -> dict[str, str]:
    modules: dict[str, str] = {}
    for d in dirs:
        for f in sorted(d.glob("*.conf")) if d.is_dir() else []:
            for line in f.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    modules[line] = f.name
    return modules


def parse_modprobe(dirs: list[Path]) -> dict[str, tuple[str, str]]:
    """(blacklist:MOD | install:MOD | options:MOD) -> (value, source)"""
    entries: dict[str, tuple[str, str]] = {}
    for d in dirs:
        for f in sorted(d.glob("*.conf")) if d.is_dir() else []:
            entries.update(_parse_modprobe_text(f.read_text(), f.name))
    return entries


def _parse_modprobe_text(text: str, source: str) -> dict[str, tuple[str, str]]:
    entries: dict[str, tuple[str, str]] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 2)
        if len(parts) < 2:
            continue
        directive, mod = parts[0], parts[1]
        if directive not in ("blacklist", "install", "options"):
            continue
        value = parts[2] if len(parts) > 2 else ""
        entries[f"{directive}:{mod}"] = (value, source)
    return entries


def parse_ssh_style(dirs: list[Path]) -> dict[str, tuple[str, str]]:
    """`Key Value` per line, shared by sshd_config.d (server, flush-left)
    and ssh_config.d (client, directives indented under a `Host *`
    header) — same directive syntax, so one parser: strip leading
    whitespace, skip the `Host` line itself."""
    entries: dict[str, tuple[str, str]] = {}
    for d in dirs:
        for f in sorted(d.glob("*.conf")) if d.is_dir() else []:
            for line in f.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or line.lower().startswith("host "):
                    continue
                parts = line.split(None, 1)
                if len(parts) == 2:
                    entries[parts[0]] = (parts[1], f.name)
    return entries


def parse_ssh_style_text(text: str) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.lower().startswith("host "):
            continue
        parts = line.split(None, 1)
        if len(parts) == 2:
            entries[parts[0]] = parts[1]
    return entries


def parse_ini(dirs: list[Path]) -> dict[str, tuple[str, str]]:
    """`[Section]` + `Key=Value`, shared by systemd unit conf.d drop-ins
    (journald/coredump/resolved/system.conf.d/...) and NetworkManager
    conf.d. Key is `Section.Key` (or just `Key` if no section header
    precedes it, e.g. a journald.extraConfig snippet with the implicit
    `[Journal]` header stripped)."""
    entries: dict[str, tuple[str, str]] = {}
    for d in dirs:
        for f in sorted(d.glob("*.conf")) if d.is_dir() else []:
            section_name = ""
            for line in f.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or line.startswith(";"):
                    continue
                if line.startswith("[") and line.endswith("]"):
                    section_name = line[1:-1]
                    continue
                if "=" not in line:
                    continue
                k, v = line.split("=", 1)
                key = f"{section_name}.{k.strip()}" if section_name else k.strip()
                entries[key] = (v.strip(), f.name)
    return entries


def parse_ini_text(text: str, implicit_section: str) -> dict[str, str]:
    entries: dict[str, str] = {}
    section_name = implicit_section
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section_name = line[1:-1]
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        key = f"{section_name}.{k.strip()}" if section_name else k.strip()
        entries[key] = v.strip()
    return entries


def parse_tmpfiles(dirs: list[Path]) -> list[tuple[str, str]]:
    """(raw line, source) — report-only, columns (type/path/mode/user/
    group/age/argument) aren't worth splitting since `argument` itself can
    contain spaces; no `systemd.tmpfiles.rules` exists in this repo to
    compare against anyway."""
    rows = []
    for d in dirs:
        for f in sorted(d.glob("*.conf")) if d.is_dir() else []:
            for line in f.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    rows.append((line, f.name))
    return rows


def parse_limits(dirs: list[Path]) -> list[tuple[str, str, str, str, str]]:
    """(domain, type, item, value, source) — no Nix-side comparison exists
    yet (security.pam.loginLimits is unused in this repo), so this is
    report-only: every row is a candidate to look at, not a pass/fail."""
    rows = []
    for d in dirs:
        for f in sorted(d.glob("*.conf")) if d.is_dir() else []:
            for line in f.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(None, 3)
                if len(parts) == 4:
                    rows.append((*parts, f.name))
    return rows


def extract_nix_env_vars() -> dict[str, str]:
    """`environment.variables.KEY = "val";` / `environment.sessionVariables.KEY
    = "val";` — dotted-path form, as used in gaming.nix. Both option names
    ultimately set an env var, so unioned for comparison against
    environment.d's flat KEY=VALUE files."""
    result: dict[str, str] = {}
    for m in re.finditer(
        r'environment\.(?:variables|sessionVariables)\.([A-Za-z_][\w-]*)\s*'
        r'=\s*(?:lib\.mk\w+\s+)?"([^"]*)"\s*;',
        ALL_NIX_TEXT,
    ):
        result[m.group(1)] = m.group(2)
    return result


def vendor_files(name: str) -> list[Path]:
    """Every file named exactly `name` under any vendored source, at any
    depth — for standalone config files that don't live in a `*.d/`
    directory (e.g. usbguard-daemon.conf)."""
    return [
        f
        for src in VENDOR_DIR.iterdir()
        if src.is_dir()
        for f in src.rglob(name)
        if f.is_file()
    ]


def vendor_dirs(leaf: str, parent: str | None = None) -> list[Path]:
    """Every directory named `leaf` under any vendored source, at any depth
    — sources nest at different levels (cachyos: usr/lib/X, secureblue:
    files/system/.../X, bazzite: system_files/desktop/shared/.../X).
    `leaf="conf.d"` alone is ambiguous (unbound/anaconda/geoclue all use
    that name too) — pass `parent="NetworkManager"` to disambiguate."""
    return [
        d
        for src in VENDOR_DIR.iterdir()
        if src.is_dir()
        for d in src.rglob(leaf)
        if d.is_dir() and (parent is None or d.parent.name == parent)
    ]


def section(title: str) -> None:
    print(f"\n{'=' * 10} {title} {'=' * 10}")


def main() -> int:
    had_diff = False

    # --- modules-load.d vs boot.kernelModules / boot.initrd.kernelModules ---
    section("modules-load.d vs boot.kernelModules")
    ours_modules = extract_nix_list("boot.kernelModules") | extract_nix_list(
        "boot.initrd.kernelModules"
    )
    upstream_modules = parse_modules_load(vendor_dirs("modules-load.d"))
    for mod, src in sorted(upstream_modules.items()):
        mark = "match" if mod in ours_modules else "not ported"
        print(f"{mod:<30} {mark:<12} ({src})")
    extra = ours_modules - set(upstream_modules)
    if extra:
        print(f"ours only (not from any vendored source): {sorted(extra)}")

    # --- modprobe.d vs boot.extraModprobeConfig + boot.blacklistedKernelModules ---
    section("modprobe.d vs boot.extraModprobeConfig / boot.blacklistedKernelModules")
    our_modprobe_text = extract_nix_string("boot.extraModprobeConfig") or ""
    ours_modprobe = _parse_modprobe_text(our_modprobe_text, "boot.extraModprobeConfig")
    for mod in extract_nix_list("boot.blacklistedKernelModules"):
        ours_modprobe[f"blacklist:{mod}"] = ("", "boot.blacklistedKernelModules")
    upstream_modprobe = parse_modprobe(vendor_dirs("modprobe.d"))
    for key, (up_val, up_src) in sorted(upstream_modprobe.items()):
        our_val, our_src = ours_modprobe.get(key, (None, None))
        if key not in ours_modprobe:
            status = "not ported"
        elif our_val != up_val:
            status = "DIFFERS"
            had_diff = True
        else:
            status = "match"
        print(f"{key:<40} {status:<12} upstream={up_val!r} ({up_src})" + (
            f" ours={our_val!r} ({our_src})" if our_src else ""
        ))

    # --- ssh/sshd_config.d vs services.openssh.settings ---
    section("sshd_config.d vs services.openssh.settings")
    ours_ssh = extract_nix_block("services.openssh", "settings")
    upstream_ssh = parse_ssh_style(vendor_dirs("sshd_config.d"))
    for key, (up_val, up_src) in sorted(upstream_ssh.items()):
        our_val = ours_ssh.get(key)
        if key not in ours_ssh:
            status = "not ported"
        elif our_val.lower() != up_val.lower():
            status = "DIFFERS"
            had_diff = True
        else:
            status = "match"
        print(f"{key:<30} {status:<12} upstream={up_val!r:<40} ours={our_val!r} ({up_src})")
    extra = set(ours_ssh) - set(upstream_ssh)
    if extra:
        print(f"ours only (not from any vendored source): {sorted(extra)}")

    # --- ssh/ssh_config.d (client) vs programs.ssh.extraConfig ---
    section("ssh_config.d vs programs.ssh.extraConfig")
    our_ssh_client_text = extract_nix_string("programs.ssh.extraConfig", anchor="programs.ssh") or ""
    ours_ssh_client = parse_ssh_style_text(our_ssh_client_text)
    upstream_ssh_client = parse_ssh_style(vendor_dirs("ssh_config.d"))
    for key, (up_val, up_src) in sorted(upstream_ssh_client.items()):
        our_val = ours_ssh_client.get(key)
        if key not in ours_ssh_client:
            status = "not ported"
        elif our_val.lower() != up_val.lower():
            status = "DIFFERS"
            had_diff = True
        else:
            status = "match"
        print(f"{key:<30} {status:<12} upstream={up_val!r:<40} ours={our_val!r} ({up_src})")
    extra = set(ours_ssh_client) - set(upstream_ssh_client)
    if extra:
        print(f"ours only (not from any vendored source): {sorted(extra)}")

    # --- systemd/journald.conf.d vs services.journald.extraConfig ---
    section("journald.conf.d vs services.journald.extraConfig")
    our_journald_text = extract_nix_string("services.journald.extraConfig") or ""
    ours_journald = parse_ini_text(our_journald_text, implicit_section="Journal")
    upstream_journald = parse_ini(vendor_dirs("journald.conf.d"))
    for key, (up_val, up_src) in sorted(upstream_journald.items()):
        our_val = ours_journald.get(key)
        if key not in ours_journald:
            status = "not ported"
        elif our_val != up_val:
            status = "DIFFERS"
            had_diff = True
        else:
            status = "match"
        print(f"{key:<30} {status:<12} upstream={up_val!r:<20} ours={our_val!r} ({up_src})")

    # --- other systemd unit conf.d + NetworkManager conf.d: report-only,
    # no Nix-side declaration exists in this repo for any of these yet ---
    section(
        "other conf.d (coredump/resolved/system.conf.d/networkd/pstore/"
        "timesyncd/user.conf.d + NetworkManager) — report-only, no Nix-side "
        "declaration exists yet"
    )
    other_conf_d = [
        "coredump.conf.d",
        "resolved.conf.d",
        "system.conf.d",
        "networkd.conf.d",
        "pstore.conf.d",
        "timesyncd.conf.d",
        "user.conf.d",
    ]
    for leaf in other_conf_d:
        for key, (val, src) in sorted(parse_ini(vendor_dirs(leaf)).items()):
            print(f"[{leaf}] {key:<30} = {val!r:<30} ({src})")
    nm_dirs = vendor_dirs("conf.d", parent="NetworkManager")
    for key, (val, src) in sorted(parse_ini(nm_dirs).items()):
        print(f"[NetworkManager/conf.d] {key:<30} = {val!r:<30} ({src})")

    # --- environment.d vs environment.variables / environment.sessionVariables ---
    section("environment.d vs environment.variables / environment.sessionVariables")
    ours_env = extract_nix_env_vars()
    upstream_env: dict[str, tuple[str, str]] = {}
    for d in vendor_dirs("environment.d"):
        for f in sorted(d.glob("*.conf")):
            for line in f.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                upstream_env[k.strip()] = (v.strip(), f.name)
    for key, (up_val, up_src) in sorted(upstream_env.items()):
        our_val = ours_env.get(key)
        if key not in ours_env:
            status = "not ported"
        elif our_val != up_val:
            status = "DIFFERS"
            had_diff = True
        else:
            status = "match"
        print(f"{key:<25} {status:<12} upstream={up_val!r:<30} ours={our_val!r} ({up_src})")

    # --- usbguard-daemon.conf vs services.usbguard.* ---
    # Only the daemon's own Key=Value config file — usbguard's rules.d
    # policy language (allow/reject/with-interface...) is procedural, not a
    # settings table, same reasoning as udev rules; not diffed.
    section("usbguard-daemon.conf vs services.usbguard.*")
    ours_usbguard = extract_nix_block("services.usbguard", "services.usbguard")
    ours_usbguard_ci = {k.lower(): v for k, v in ours_usbguard.items()}
    for f in vendor_files("usbguard-daemon.conf"):
        for key, up_val in parse_ini_text(f.read_text(), implicit_section="").items():
            our_val = ours_usbguard_ci.get(key.lower())
            if key.lower() not in ours_usbguard_ci:
                status = "not ported"
            elif our_val.lower() != up_val.lower():
                status = "DIFFERS"
                had_diff = True
            else:
                status = "match"
            print(f"{key:<26} {status:<12} upstream={up_val!r:<20} ours={our_val!r} ({f.name})")

    # --- security/limits.d: report-only, no Nix-side comparison exists ---
    section("security/limits.d (report-only — this repo sets no security.pam.loginLimits)")
    for domain, typ, item, value, src in parse_limits(vendor_dirs("limits.d")):
        print(f"{domain:<10} {typ:<6} {item:<10} {value:<10} ({src})")

    # --- tmpfiles.d: report-only, no systemd.tmpfiles.rules in this repo ---
    section("tmpfiles.d (report-only — this repo sets no systemd.tmpfiles.rules)")
    for line, src in parse_tmpfiles(vendor_dirs("tmpfiles.d")):
        print(f"{line:<60} ({src})")

    print(f"\n{'DIFFERS found — see above' if had_diff else 'no DIFFERS'}")
    return 1 if had_diff else 0


if __name__ == "__main__":
    sys.exit(main())
