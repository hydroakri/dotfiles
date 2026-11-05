#!/usr/bin/env bash
# Validates the Home Assistant config of a host with HA's own check_config on x86; nothing for arm64 is built.
# Run from the repo root: flake/modules/features/home-assistant/check_config.sh [host]
set -euo pipefail

host=${1:-rpi4-switch}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
attr="./flake#nixosConfigurations.$host.config.services.home-assistant"

components=$(nix eval --json "$attr.extraComponents")
ha=$(nix build --no-link --print-out-paths --impure --expr "let f = builtins.getFlake (toString ./flake); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.home-assistant.override { extraComponents = builtins.fromJSON ''$components''; }")
# check_config insists on colorlog and cannot pip-install it here
colorlog=$(nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./flake); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.python3Packages.colorlog')

mkdir "$work/conf"
nix eval --json "$attr.config" | python3 -I -c '
import json, sys
def drop_null(x):
    # The NixOS module unquotes "!include ..." strings; an empty list stands in for the included file.
    if isinstance(x, str) and x.startswith("!include "):
        return []
    if isinstance(x, dict):
        return {k: drop_null(v) for k, v in x.items() if v is not None}
    if isinstance(x, list):
        return [drop_null(v) for v in x]
    return x
json.dump(drop_null(json.load(sys.stdin)), sys.stdout)
' >"$work/conf/configuration.yaml"

out=$(PYTHONPATH=$(echo "$colorlog"/lib/python3*/site-packages) "$ha/bin/hass" --script check_config -c "$work/conf" 2>&1 || true)
out=$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g')
if printf '%s\n' "$out" | grep -E 'failed to setup|Invalid config|extra keys|not allowed|Failed config'; then
  echo "check_config: problems found" >&2
  exit 1
fi
echo "check_config: no automation or schema errors"
echo "(requirement warnings for frontend, openai or Pillow come from the minimal environment)"
