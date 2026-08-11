#!/usr/bin/env bash
# Re-vendor upstream config trees for every source below. Shallow-clones
# each repo and vendors it into (gitignored) docs/upstream-vendor/<name>/,
# then rewrites SOURCE.md with the commit/date actually fetched. Re-run
# this at the start of each quarterly review.
#
# One pass, no path list, no per-source special-casing: every file in the
# clone (minus .git, minus anything over the size cap) gets vendored,
# wherever it lives. Earlier this anchored on directories literally named
# `etc`/`usr`, which missed real config living outside a POSIX rootfs
# layout — e.g. secureblue's `files/gschema-overrides/*.override`. Scanning
# the whole repo catches that too, at the cost of also vendoring source
# code / CI / packaging files alongside the config — harmless, since the
# diff scripts find their target directories by name (`rglob()`) rather
# than trusting everything vendored to be relevant, and the size cap below
# already keeps this cheap. When a source adds some new config category
# upstream, it just shows up on the next refresh; nothing here needs an
# edit for that.
set -euo pipefail

vendor_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# name | repo url | branch | license file in repo root | SPDX id
sources=(
  "cachyos|https://github.com/CachyOS/CachyOS-Settings.git|master|LICENSE.md|GPL-3.0"
  "kicksecure|https://github.com/Kicksecure/security-misc.git|master|COPYING|AGPL-3.0-or-later"
  "secureblue|https://github.com/secureblue/secureblue.git|live|LICENSE|Apache-2.0"
  "bazzite|https://github.com/ublue-os/bazzite.git|main|LICENSE|Apache-2.0"
  "nix-mineral|https://github.com/cynicsketch/nix-mineral.git|main|LICENSE|GPL-3.0"
  "pop-default-settings|https://github.com/pop-os/default-settings.git|master|LICENSE.md|GPL-3.0"
  "grapheneos-infra|https://github.com/GrapheneOS/infrastructure.git|main|LICENSE|MIT"
)

# Config files are always small text; a 256K cap is generous headroom over
# the largest real one seen so far (Kicksecure's 990-security-misc.conf,
# ~31K) while excluding the multi-MB wallpapers/video/firmware blobs distro
# repos also ship under usr/share. A size filter is a content-type check,
# not a category allowlist — it doesn't reintroduce per-source path
# enumeration, it just skips things that can never be config regardless of
# where they live.
MAX_BYTES=262144

vendor_whole_repo() {
  local clone="$1" dest="$2"
  local rel target base
  find "$clone" -type f -not -path '*/.git/*' -size -${MAX_BYTES}c | while read -r f; do
    rel="${f#"$clone"/}"
    # Kicksecure ships some files as `name.conf#security-misc-shared` —
    # strip the packaging suffix so the filename matches the real install
    # location. Some also stack a *second* `.security-misc` suffix before
    # that (e.g. `usbguard-daemon.conf.security-misc#security-misc-shared`,
    # `faillock.conf.security-misc#...`) — strip that too, but only as an
    # exact trailing suffix (`${base%.security-misc}` is a literal-string
    # match, not a substring search), so it doesn't clip files where
    # "security-misc" is a real part of the name followed by a real
    # extension, like `30_security-misc.conf` or `30_security-misc.sh`.
    base="$(basename "$rel")"
    base="${base%%#*}"
    base="${base%.security-misc}"
    target="$dest/$(dirname "$rel")/$base"
    mkdir -p "$(dirname "$target")"
    cp "$f" "$target"
  done
}

for entry in "${sources[@]}"; do
  IFS='|' read -r name url branch license_file license_id <<<"$entry"
  dest="$vendor_dir/$name"
  clone="$work/$name"

  git clone --quiet --depth 1 --branch "$branch" "$url" "$clone"
  commit="$(git -C "$clone" rev-parse HEAD)"
  date="$(date -u +%Y-%m-%dT%H:%MZ)"

  mkdir -p "$dest"
  find "$dest" -mindepth 1 -not -name 'SOURCE.md' -delete

  vendor_whole_repo "$clone" "$dest"

  if [ -f "$clone/$license_file" ]; then
    cp "$clone/$license_file" "$dest/LICENSE.upstream"
  fi

  file_count="$(find "$dest" -type f | wc -l)"

  cat >"$dest/SOURCE.md" <<EOF
# $name

- Repo: $url
- Branch: $branch
- Commit: $commit
- Fetched: $date
- Vendored: entire repo (minus .git, minus files over ${MAX_BYTES} bytes) — $file_count files
- License: $license_id (see \`LICENSE.upstream\` in this directory — NOT this
  repo's top-level MIT license; these files are third-party content, see
  ../README.md "Licensing")

Re-run \`docs/upstream-vendor/refresh.sh\` to update. Files here are kept
byte-identical to upstream (packaging suffixes stripped) — do not hand-edit.
EOF

  echo "vendored $name @ $commit ($file_count files)"
done
