#!/usr/bin/env python3
"""Diff sysctl keys declared in flake/modules/features/*.nix against every
vendored upstream source in docs/upstream-vendor/.

Only sysctl is automated: it's a clean `key = value` table on every side,
including nix-mineral (Nix source, parsed with the same key regex used for
this repo). udev rules and modprobe.d stay a manual diff (rule syntax, not
a settings table); Kconfig-based sources (Pop!_OS, hardened-kernel, ...)
aren't diffable as flat files at all and aren't pursued at all here — any
finding would mean maintaining kernel patches/config overrides, not a
one-line Nix change, and this repo already builds its own CachyOS kernel
rather than any of these distros' kernel, so the payoff doesn't justify
that maintenance burden. See "Kernel Kconfig" in docs/upstream-settings.md.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
VENDOR_DIR = Path(__file__).resolve().parent
FEATURES_DIR = REPO_ROOT / "flake" / "modules" / "features"

# Only treat quoted dotted keys under these top-level sysctl namespaces as
# sysctl assignments, to avoid matching unrelated quoted Nix strings.
SYSCTL_NAMESPACES = {
    "kernel", "net", "vm", "dev", "fs", "abi", "debug", "user", "crypto",
}

# Matches both `lib.mkOverride N value` (this repo) and `l.mkOverride N value`
# (nix-mineral aliases lib as l).
NIX_KEY_RE = re.compile(
    r'"(?P<key>[a-zA-Z][\w.\*/-]*\.[\w.\*/-]+)"\s*=\s*'
    r'(?:l(?:ib)?\.mk(?:Override\s+\d+|Default|Force)\s+)?'
    r'(?P<value>\((?:-?\d+)\)|"[^"]*"|-?\d+|true|false)\s*;'
)

CONF_LINE_RE = re.compile(r'^\s*([\w.\*/-]+)\s*=\s*(.+?)\s*$')

# Sources that ship flat sysctl.d conf files, vendored verbatim by refresh.sh.
CONF_SOURCES = ["cachyos", "kicksecure", "secureblue", "bazzite", "pop-default-settings", "grapheneos-infra"]
# Sources that are Nix, parsed with NIX_KEY_RE like this repo's own modules.
NIX_SOURCES = ["nix-mineral"]


def norm_value(v: str) -> str:
    v = v.strip()
    if v.startswith("(") and v.endswith(")"):
        v = v[1:-1].strip()
    if v.startswith('"') and v.endswith('"'):
        v = v[1:-1]
    if v == "true":
        v = "1"
    elif v == "false":
        v = "0"
    return v


def parse_nix_tree(root: Path, *, restrict_namespace: bool) -> dict[str, tuple[str, str]]:
    """key -> (value, "relative/file.nix:line"), last assignment wins."""
    found: dict[str, tuple[str, str]] = {}
    if not root.is_dir():
        return found
    for path in sorted(root.rglob("*.nix")):
        rel = path.relative_to(root)
        for lineno, line in enumerate(path.read_text().splitlines(), start=1):
            m = NIX_KEY_RE.search(line)
            if not m:
                continue
            key = m.group("key")
            if restrict_namespace and key.split(".", 1)[0] not in SYSCTL_NAMESPACES:
                continue
            found[key] = (norm_value(m.group("value")), f"{rel}:{lineno}")
    return found


def parse_conf_dirs(*dirs: Path) -> dict[str, tuple[str, str]]:
    """key -> (value, "relative/file.conf"), last assignment wins."""
    found: dict[str, tuple[str, str]] = {}
    for conf_dir in dirs:
        if not conf_dir.is_dir():
            continue
        for path in sorted(conf_dir.rglob("*.conf")):
            for line in path.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                m = CONF_LINE_RE.match(line)
                if not m:
                    continue
                key, value = m.group(1), m.group(2)
                found[key] = (value.strip(), path.name)
    return found


def load_sources() -> dict[str, dict[str, tuple[str, str]]]:
    sources: dict[str, dict[str, tuple[str, str]]] = {}
    for name in CONF_SOURCES:
        sysctl_dirs = list((VENDOR_DIR / name).rglob("sysctl.d"))
        sources[name] = parse_conf_dirs(*sysctl_dirs)
    for name in NIX_SOURCES:
        sources[name] = parse_nix_tree(VENDOR_DIR / name, restrict_namespace=True)
    return sources


def main() -> int:
    ours = parse_nix_tree(FEATURES_DIR, restrict_namespace=True)
    upstream = load_sources()
    source_names = list(upstream.keys())

    all_keys = sorted(set(ours) | set().union(*[set(d) for d in upstream.values()]))

    rows = []
    for key in all_keys:
        our_v, our_src = ours.get(key, (None, None))
        vals = {name: upstream[name].get(key, (None, None))[0] for name in source_names}

        if key not in ours:
            status = "not ported"
        elif any(v is not None and v != our_v for v in vals.values()):
            status = "DIFFERS"
        else:
            status = "match"

        rows.append((key, status, our_v, our_src, vals))

    only_upstream = [r for r in rows if r[0] not in ours]
    differs = [r for r in rows if r[1] == "DIFFERS"]
    matches = [r for r in rows if r[1] == "match"]

    w = max(len(k) for k in all_keys) + 2

    def p(row):
        key, status, our_v, our_src, vals = row
        val_str = " ".join(f"{name}={vals[name]!r}" for name in source_names)
        print(f"{key:<{w}} {status:<11} ours={our_v!r:<20} {val_str} ({our_src or '-'})")

    if differs:
        print(f"=== DIFFERS ({len(differs)}) — value in this repo disagrees with an upstream source ===")
        for r in differs:
            p(r)
        print()

    print(f"=== only upstream, not ported ({len(only_upstream)}) ===")
    for r in only_upstream:
        p(r)
    print()

    print(f"=== match ({len(matches)}) ===")
    for r in matches:
        p(r)
    print()

    print(
        f"total: {len(all_keys)} keys across {', '.join(source_names)} | "
        f"{len(matches)} match | {len(differs)} differ | {len(only_upstream)} not ported"
    )
    return 1 if differs else 0


if __name__ == "__main__":
    sys.exit(main())
