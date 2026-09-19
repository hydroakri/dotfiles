# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

- `flake/` — multi-host NixOS flake (4 hosts: `omen15` desktop, `oci` cloud server, `rpi4-side-gateway`, `rpi4-switch`). Excluded from chezmoi deployment (`.chezmoiignore`).
- Everything else (`dot_config/`, `dot_zshrc`, `dot_zsh_plugins.txt`) — chezmoi-managed dotfiles.
- `utils/` — provisioning scripts, excluded from chezmoi deployment; must be copied to `~/utils/` manually (WM configs hardcode this path).

Read `README.md` first for the module table and dotfile gotchas.

## Commands

```bash
# Build and switch a host (run from repo root, not inside flake/)
nh os switch -H omen15 ./flake
nh os switch -H oci ./flake

# Build without activating (fast correctness check after editing modules)
nixos-rebuild build --flake ./flake#omen15

# Check flake evaluates for all hosts (cheap sanity check, no build)
nix flake check ./flake

# Format nix files
nix fmt ./flake

# Update flake inputs
nix flake update --flake ./flake

# Secrets (sops-nix) — run from flake/modules/features/secrets/
sops secrets.yaml            # edit
sops updatekeys secrets.yaml # re-encrypt after changing .sops.yaml recipients

# Dotfiles
chezmoi diff
chezmoi apply
chezmoi apply ~/.config/niri   # single target
```

No test suite. Correctness = `nixos-rebuild build` succeeding + CI building all four hosts on push to `main`.

## Rules

### Verification

- Nix change (`flake/**`) → run `nixos-rebuild build --flake ./flake#<host>` (or `nix flake check ./flake`) before calling it done.
- Non-nix change (dotfiles, `dot_config/`, `dot_zshrc`, `utils/`) → do **not** run `nix flake check` or `nixos-rebuild build`; it's irrelevant to those paths. `chezmoi diff`/`chezmoi apply` is the only check needed.
- Never present a fix as root-caused until it's tested against live behavior, not just judged plausible from source. Two wrong "confident" fixes in a row on the same symptom = stop guessing, reproduce directly (run the binary by hand, curl the endpoint) before a third attempt.
- Debug with safe, non-mutating commands first (logs, status, dry-run, read-only checks) to gather evidence before changing any config or state — don't jump straight to an edit-and-see fix loop.
- A check that doesn't exercise the actual failure mode isn't verification. E.g. `restic check --read-data-subset` only proves a backup repo isn't corrupted, not that a restore produces usable data — for anything claimed "verified," confirm against the real thing it needs to survive (actually restore it, actually run the binary, actually hit the endpoint).
- On a branch used for external device/hardware testing: don't commit or push a fix until the user explicitly confirms the overall test passed. A reported test *failure* is not permission to commit.
- Destructive verification steps (restore → inspect → cleanup): separate commands, never bundled — cleanup must not run before the result is inspected.

### Secrets (sops-nix)

- Never decrypt. No `sops -d`, `sops secrets.yaml`, `--decrypt`, or anything that reveals plaintext — not even to confirm a key exists. Check presence structurally (encrypted key names, `.sops.yaml` recipients), or have the user run the command and report back.
- Never rotate a secret that's fixed after first use without asking first (check the app's own docs — some secrets are baked into already-encrypted data at creation and rotating breaks it).
- Any secret read via bare `._secret`/`.path` (not `sops.placeholder`) by a non-root service needs that service's `owner` set explicitly — sops-nix defaults to `root:root 0400`.
- Don't add/remove/re-encrypt `.sops.yaml` recipients (no `sops updatekeys`) without user confirmation — it changes who can decrypt every secret in the file.

### Module boundaries

- `modules/desktop.nix` and `modules/server.nix` are mutually exclusive — never import both on one host.
- `core`, `desktop`/`server`, `performance`, `security`, `privacy`, `gaming`, `filesystem-btrfs`, `hardware-amd` are always-active once imported (no enable flag) — a change here applies to every host importing it, not just the one you're focused on.
- `virtualisation`: podman + aarch64 binfmt are always-on once imported; KVM/QEMU + libvirtd is gated behind `modules.virtualisation.libvirtd.enable` (default `false`).
- Renaming or changing the default of an option exposed under `nixosModules` (`flake/flake.nix`) is a breaking change for external consumers — treat it as higher-risk than an internal-only option rename.
- Networking feature modules (`networking-sqm`, `networking-tuning`, `networking-router`, `networking-proxy`) can touch the same NIC/qdisc/sysctl surface — check the others aren't already configuring the same interface before adding to one.

### Comments and docs

- Comments/docs: facts only. No investigation narrative, no dated "compared X against Y" citations.
- Inline `.nix` comments: non-obvious WHY only, 1-2 lines max. Longer rationale (design tradeoffs, redeploy gotchas) goes in that host's `README.md`, not a growing comment block.
- Tradeoff/decision records: one compact table, not prose duplicated across files.

### Ad-hoc tooling

- Missing CLI tool → run it via `, <cmd> <args>` (nix-comma) instead of asking to install or declaring it unavailable.
- If output must be piped/captured, use `nix shell nixpkgs#<pkg> --command <tool> ...` instead — `,` needs a real tty and fails silently (empty output) when piped in a non-interactive call.
