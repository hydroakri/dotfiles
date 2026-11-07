# omen15

## VM optimizations (default on) and RTX 3060 passthrough (`vfio` boot entry)

Module: [`vfio-passthrough.nix`](../../modules/features/vfio-passthrough.nix). `modules.vfio.enable` is on by default and applies to every boot entry: the Nix-generated `win11` domain (pinning, Hyper-V, virtio-scsi, TPM), `kvm ignore_msrs`, Looking Glass shm. GPU passthrough is the optional `modules.vfio.gpuPassthrough.enable` switch, set only by `specialisation.vfio`; the devices and SMBIOS strings are declared once in the main config. Without passthrough the domain uses the emulated QXL display.

### Use

1. For GPU passthrough: reboot, pick the `vfio` entry in limine. `lspci -nnk -s 01:00` must show `vfio-pci` on both functions.
2. The `libvirt-define-win11` unit defines the domain at boot. `virsh -c qemu:///system start win11`, or start it in virt-manager.
3. Windows: install the Looking Glass host (B7) and virtio-win drivers; `looking-glass-client` on the host.

The domain is redefined from Nix at every boot, so virt-manager edits do not persist; change options instead. A same-name domain with another UUID must be removed first: `virsh undefine win11 --nvram`.

### Options worth knowing

| Option | Default | Note |
| --- | --- | --- |
| `vm.memoryMiB` | 6144 | Host has about 13 GB; the guide's 8 GB leaves too little for the desktop. |
| `vm.cpu.guestCores` / `hostCores` | `[4 5 6 7]` / `[0 1 2 3]` | Physical cores; threads `2N,2N+1` (verified via sysfs) are pinned together. Emulator and iothread stay on `hostCores`. |
| `hugepages.enable` | off | Reserves `memoryMiB/2` 2 MiB pages at boot (3072 = 6 GB); that RAM is unavailable to the host for the whole boot. |
| `kvm.ignoreMsrs` | on | Applies to every guest on the host. |
| `kvm.allowUnsafeInterrupts` | off | Not needed with AMD-Vi interrupt remapping; weakens isolation. |
| `lookingGlass.sizeMiB` | 64 | B7: 32 MiB for 1080p SDR. |
| `vm.hideHypervisor` | on | Clears CPUID hypervisor bit, hides KVM, sets SMBIOS strings (no serials). |
| `vm.emulatedVideo` | on | QXL kept as a fallback console. |
| `vm.network.model` | `e1000e` | `virtio` needs virtio-win in the guest. |
| `vm.disk.sizeGiB` | null (omen15: 80) | Creates a sparse image at boot if missing; null never creates one. |
| `vm.disk.bus` | `scsi` | virtio-scsi needs vioscsi at install time; `sata` for an existing image without virtio drivers. |
| `vm.installMedia` | empty | ISO paths attached as SATA CD-ROMs; the first boots after the empty disk. |
| `vm.virtioWin.enable` | on | Slim Win10/11 virtio-win ISO built from nixpkgs, attached as a CD-ROM (load vioscsi/viostor from it in setup). |

### Decisions

| Topic | Decision | Reason |
| --- | --- | --- |
| Domain definition | `virsh define` oneshot of a Nix-generated XML | No new flake input, no lock or CI change. |
| Guide's modprobe `iommu=pt amd_iommu=on` | Kernel parameters instead | They are not module options. |
| Guide's `vfio_virqfd` | Not loaded | Merged into `vfio` in current kernels. |
| Guide's third hostdev (host NVMe) | Not carried over | Only the dGPU pair is passed through. |
| Guide's fake SMBIOS serials | Not carried over | Not real hardware data. |
| `libvirtd` qemu `user =` | Not set | `runAsRoot = true` on this host; the shm file is group `qemu-libvirtd` so `runAsRoot = false` also works. |
| `isolcpus` | Not set | Host stays fully schedulable; pinning alone. |

### Risks

- The dGPU is unavailable to the host in this entry (no PRIME offload, no CUDA).
- Looking Glass captures the dGPU output; a laptop dGPU may have no display connector for the guest, so a dummy HDMI plug or an external monitor on a dGPU-wired port can be needed.
- Mobile GPUs may need `modules.vfio.devices.*.romfile` (patched vBIOS) to initialise in the guest.
- Unverified: with the hypervisor bit hidden Windows may ignore the Hyper-V enlightenments; set `vm.hideHypervisor = false` if guest timing or performance is off.
