> Useful utils  
> `earlyoom` `adguardhome` `warp-svc` `systemd-resolved` `gamemode`

```
sudo systemctl daemon-reload
sudo systemctl enable fstrim.timer
sudo systemctl enable systemd-zram-setup@zram0.service
sudo systemctl enable nvidia-suspend.service
```

> /etc/default/grub

```conf
GRUB_CMDLINE_LINUX_DEFAULT="rootfstype=xfs zswap.enabled=0 mem_sleep_default=s2idle radeon.dpm=1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1 amd_pstate=active mitigations=on nowatchdog processor.ignore_ppc=1 nmi_watchdog=0 apparmor=1 security=apparmor lockdown=integrity quiet splash"
```

> /etc/modprobe.d/nvidia-options.conf

```
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
```

> /etc/systemd/zram-generator.conf

```
[zram0]
zram-size = ram/2
compression-algorithm = zstd
```

> /etc/sysctl.conf

```conf
kernel.core_pattern=|/bin/false # Disabling automatic core dumps
kernel.unprivileged_bpf_disabled = 0
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr2

net.core.netdev_max_backlog = 16384
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216
net.core.wmem_default = 1048576
net.core.wmem_max = 16777216
net.core.optmem_max = 65536
net.ipv4.tcp_rmem = 4096 1048576 2097152
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1

vm.swappiness=180
vm.watermark_boost_factor=0
vm.watermark_scale_factor=125
vm.page-cluster=0

vm.dirty_ratio=8
vm.dirty_background_ratio=4
vm.dirty_writeback_centisecs=1500
vm.dirty_expire_centisecs=1500
vm.laptop_mode=5
vm.vfs_cache_pressure = 50
```

> /etc/modules-load.d/tcp_bbr.conf

```conf
tcp_bbr2
zram
```

> /etc/fstab

```
<type>  <options>
ntfs3 uid=1000,gid=1000,rw,user,exec,umask=000,prealloc
btrfs rw,relatime,ssd,space_cache=v2,noatime,commit=120,compress=zstd,discard=async
```

> /etc/environment

```
XMODIFIERS=@im=fcitx
```

> kernel modules

```
amdgpu
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
```

## Another important thing

```
pacman -Qqe > pkgs.txt
flatpak list --columns=app > flatpak.txt
sudo apt list > debs.txt
brew list > brew.txt
```
