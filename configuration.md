# Useful utils

> use ssh as default for github

```shell
git config --global url.ssh://git@github.com/.insteadOf https://github.com/
```

> `earlyoom` `adguardhome` `warp-svc` `systemd-resolved` `gamemode` `gufw` `apparmor` `proxychains` `preload` `dnscrypt-proxy` 

```shell
sudo systemctl daemon-reload
sudo systemctl enable fstrim.timer
sudo systemctl enable systemd-zram-setup@zram0.service
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable systemd-resolved.service
sudo systemctl enable preload.service
```

# Kernel settings

> /etc/default/grub

```conf
GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=0 radeon.dpm=1 amd_pstate=active processor.ignore_ppc=1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1 nouveau.config=NvGspRm=1 nouveau.config=NvBoost=2 mem_sleep_default=s2idle nowatchdog nmi_watchdog=0 iwlwifi.power_save=1 mitigations=auto apparmor=1 security=apparmor lockdown=integrity quiet splash"

# WARNING: lockdown=integrity can cause modules that out of tree not be load(such as nvidia)
```

> /etc/modprobe.d/nvidia-options.conf

```conf
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
```

> early kernel modules:  
> /etc/initramfs-tools/modules (Debian) /etc/mkinitcpio.conf(Arch Linux)

```conf
amdgpu
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
```
or  
> /etc/dracut.conf.d/modules.conf
`sudo dracut -f`
```conf
add_drivers+=" amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm "
```

> /etc/modules-load.d/mods.conf

```conf
zram
```

> /etc/sysctl.conf

```conf
#security
kernel.core_pattern=|/bin/false
kernel.unprivileged_bpf_disabled=0
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=3
kernel.kexec_load_disabled=1
module.sig_enforce=1
net.core.bpf_jit_harden=2

# performance
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr2

net.core.somaxconn = 256
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

# Systemd settings

> /etc/systemd/zram-generator.conf

```conf
[zram0]
zram-size = ram/2
compression-algorithm = zstd
```

> /etc/NetworkManager/conf.d/dns.conf

```
[main]
dns=none
```

> /etc/systemd/resolved.conf

```
[Resolve]
DNS=123.129.227.3#doh.apad.pro 103.2.57.5#ipublic.dns.iij.jp 101.102.103.104#101.101.101.101 1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google 9.9.9.9#dns.quad9.net
Domains=~
DNSSEC=allow-downgrade
DNSOverTLS=yes
MulticastDNS=yes
LLMNR=yes
Cache=yes
```

# Udev rules

> /etc/udev/rules.d/powersave.rules

```
SUBSYSTEM=="pci", ATTR{power/control}="auto"

# 上述规则会关闭所有未使用的设备，但某些设备不会再次唤醒。要仅对已知可以工作的设备进行运行时电源管理，请使用对应供应商和设备ID的简单匹配（使用 lspci -nn 获取这些值)

ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="/usr/bin/iw dev $name set power_save on"

# disable Wake-on-LAN
```

> /etc/udev/rules.d/ntfs3_by_default.rules

```
# SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="ntfs", ENV{ID_FS_TYPE}="ntfs3"

# WARNING: ntfs-3g is more reliable than ntfs3 you are recommended assigning fs type mannually in /etc/fstab
```

# Other /etc files

> /etc/environment

```
XMODIFIERS=@im=fcitx
```

> /etc/fstab

```
<type>  <options>
ntfs-3g nofail,users,uid=1000,gid=1000,rw,exec,umask=000,prealloc,windows_names,noatime,allow_other,async,big_writes
ntfs3 uid=1000,gid=1000,rw,user,exec,umask=000,prealloc,nofail
btrfs rw,relatime,ssd,space_cache=v2,noatime,commit=120,compress=zstd,discard=async
# WARNING: some distro do not support ntfs, add to fstab can boot into emergency shell
```

# distro specific

> /etc/apt/source.list

```list
#local-mirror
deb http://mirrors.ustc.edu.cn/debian trixie main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian trixie-updates main contrib non-free non-free-firmware

#main-source/updates/backports
deb https://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ trixie-backports main contrib non-free non-free-firmware

#security
deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
```

## Package Manager etc.

```
pacman -Qqe > pkgs.txt
flatpak list --columns=app > flatpak.txt
apt-mark showmanual > debs.txt
brew list > brew.txt

# after backup
xargs -a pkgs.txt pacman -S
xargs -a flatpak.txt flatpak install -y
xargs -a debs.txt nala install -y
xargs -a brew.txt brew install
```

## Flatpak Override
If you want Flatpak application to use discrete GPU you need to add `--device=dri` and necessary variable to override.
```
flatpak override \
  --user \
  --device=dri \
  --filesystem=~/steamlib \
  --env=__NV_PRIME_RENDER_OFFLOAD=1 \
  --env=__GLX_VENDOR_LIBRARY_NAME=nvidia \
  com.valvesoftware.Steam
```

# Secure boot

hook for auto sign for custom kernel:

> /etc/initramfs-tools/hooks/sb-sign

```sh
#!/bin/sh
PREREQ=""
prereqs()
{
        echo "$PREREQ"
}
case $1 in
prereqs)
        prereqs
        exit 0
        ;;
esac
. /usr/share/initramfs-tools/hook-functions
# Begin real processing below this line

# 定义证书和密钥的路径
cert="/root/MOK.crt"
key="/root/MOK.key"

# 扫描 /boot 目录下的文件并使用 file 命令识别内核文件
for file in /boot/*; do
    if [ -f "$file" ]; then
        # 使用 file 命令检查文件类型
        if file "$file" | grep -q "Linux kernel"; then
            sbverify --cert "$cert" "$file"
            case $? in
                0)
                    echo "File already signed: $file"
                    ;;
                1)
                    echo "File not signed, signing: $file"
                    sbsign --key "$key" --cert "$cert" --output "$file" "$file"
                    ;;
                *)
                    echo "Error: $file"
                    ;;
            esac
        fi
    fi
done
```

```
sudo chmod 755 /etc/initramfs-tools/hooks/sb-sign

#创建一个机器所有者密钥（MOK）：
openssl req -newkey rsa:4096 -nodes -keyout /root/MOK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Machine Owner Key/" -out /root/MOK.crt
openssl x509 -outform DER -in /root/MOK.crt -out /root/MOK.cer

sbsign --key /root/MOK.key --cert /root/MOK.crt --output esp/EFI/BOOT/grubx64.efi esp/EFI/BOOT/grubx64.efi
WARNING：你需要把key的位置和esp分区的位置替换为实际情况

#执行完以下两条一定要自然重启并输入密码，使其配置密钥
sudo mokutil --import /var/lib/dkms/mok.pub #dkms的公钥用于签名树外模块
sudo mokutil --import MOK.cer
```

> /etc/unbound/unbound.conf

```conf
include-toplevel: "/etc/unbound/unbound.conf.d/*.conf"

server:
    qname-minimisation: yes
    interface: 0.0.0.0
    port:5353
    access-control: 0.0.0.0/24 allow
    cache-max-ttl: 3600
    edns-buffer-size: 1480
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    fast-server-permil: 618
    fast-server-num: 300
    harden-dnssec-stripped: yes
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    # Optimize
    # use all CPUs
    num-threads: 8
    # power of 2 close to num-threads
    msg-cache-slabs: 64
    rrset-cache-slabs: 64
    infra-cache-slabs: 64
    key-cache-slabs: 64
    # more cache memory, rrset=msg*2
    rrset-cache-size: 100m
    msg-cache-size: 50m
    # more outgoing connections
    # depends on number of cores: 1024/cores - 50
    outgoing-range: 78
    # Larger socket buffer.  OS may need config.
    so-rcvbuf: 4m
    so-sndbuf: 4m
    # Faster UDP with multithreading (only on Linux).
    so-reuseport: yes

remote-control:
    # allows controling unbound using "unbound-control"
    control-enable: yes

forward-zone:
    name: "."
    forward-tls-upstream: yes
```

> /etc/dnscrypt-proxy/dnscrypt-proxy.toml
Please DO don't forget to enable socket
```
# Empty listen_addresses to use systemd socket activation
listen_addresses = []
block_ipv6 = true
lb_strategy = 'p2'
server_names = [
'cloudflare',
'cloudflare-family',
'cloudflare-security',
'mullvad-adblock-doh',
'mullvad-all-doh',
'mullvad-base-doh',
'mullvad-doh',
'mullvad-extend-doh',
'mullvad-family-doh',
'nextdns',
'nextdns-ultralow',
'controld-block-malware',
'controld-block-malware-ad',
'controld-block-malware-ad-social',
'controld-family-friendly',
'controld-uncensored',
'controld-unfiltered',
'dns0',
'dns0-kid',
'dns0-unfiltered',
'adguard-dns-doh',
'adguard-dns-family-doh',
'adguard-dns-unfiltered-doh',
'quad9-dnscrypt-ip4-filter-ecs-pri',
'quad9-dnscrypt-ip4-filter-pri',
'quad9-dnscrypt-ip4-nofilter-ecs-pri',
'quad9-dnscrypt-ip4-nofilter-pri',
'quad9-doh-ip4-port443-filter-ecs-pri',
'quad9-doh-ip4-port443-filter-pri',
'quad9-doh-ip4-port443-nofilter-ecs-pri',
'quad9-doh-ip4-port443-nofilter-pri',
'quad9-doh-ip4-port5053-filter-ecs-pri',
'quad9-doh-ip4-port5053-filter-pri',
'quad9-doh-ip4-port5053-nofilter-ecs-pri',
'quad9-doh-ip4-port5053-nofilter-pri',
'rethinkdns-doh',
]

[query_log]
  file = '/var/log/dnscrypt-proxy/query.log'

[nx_log]
  file = '/var/log/dnscrypt-proxy/nx.log'

[sources]
  [sources.'public-resolvers']
  url = 'https://download.dnscrypt.info/dnscrypt-resolvers/v3/public-resolvers.md'
  cache_file = '/var/cache/dnscrypt-proxy/public-resolvers.md'
  minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
  refresh_delay = 72
  prefix = ''

[blocked_names]
  blocked_names_file = '/var/cache/dnscrypt-proxy/blocklist.txt'
```
