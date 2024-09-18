# Useful utils

> use ssh as default for github

```shell
git config --global url.ssh://git@github.com/.insteadOf https://github.com/
```

> `earlyoom` `adguardhome` `warp-svc` `systemd-resolved` `gamemode` `gufw` `apparmor` `proxychains` `preload`

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
ntfs3 uid=1000,gid=1000,rw,user,exec,umask=000,prealloc
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

## Another important thing

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
    access-control: 0.0.0.0/24 allow
    num-threads: 8
    num-queries-per-thread: 4096
    verbosity: 4
    val-log-level: 2
    so-rcvbuf: 8m
    so-sndbuf: 8m
    so-reuseport: yes
    cache-max-ttl: 3600
    outgoing-num-tcp: 1024
    incoming-num-tcp: 1024
    edns-buffer-size: 1480
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    fast-server-permil: 618
    harden-dnssec-stripped: yes
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

remote-control:
    # allows controling unbound using "unbound-control"
    control-enable: yes

forward-zone:
    name: "."
    forward-tls-upstream: yes
    # Rethinkdns
    forward-addr: 137.66.7.89@853#max.rethinkdns.com
    forward-addr: 172.67.214.246@443#basic.rethinkdns.com
    forward-addr: 104.21.83.62@443#basic.rethinkdns.com
    # blahdns Singapore
    forward-addr: 46.250.226.242@853#dot-sg.blahdns.com
    forward-addr: 2407:3640:2205:1668::1@853#dot-sg.blahdns.com
    forward-addr: 104.21.71.180@443#doh-sg.blahdns.com
    forward-addr: 172.67.147.247@443#doh-sg.blahdns.com
    # blashdns German
    forward-addr: 78.46.244.143@853#dot-de.blahdns.com
    forward-addr: 78.46.244.143@443#doh-de.blahdns.com
    forward-addr: 2a01:4f8:c17:ec67::1@853#dot-de.blahdns.com
    # Quad9
    forward-addr: 9.9.9.9@443#dns.quad9.net
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 9.9.9.10@443#dns10.quad9.net
    forward-addr: 9.9.9.10@853#dns10.quad9.net
    forward-addr: 9.9.9.11@443#dns11.quad9.net
    forward-addr: 9.9.9.11@853#dns11.quad9.net
    forward-addr: 149.112.112.112@443#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
    forward-addr: 149.112.112.10@443#dns10.quad9.net
    forward-addr: 149.112.112.10@853#dns10.quad9.net
    forward-addr: 149.112.112.11@443#dns11.quad9.net
    forward-addr: 149.112.112.11@853#dns11.quad9.net
    forward-addr: 2620:fe::fe@443#dns.quad9.net
    forward-addr: 2620:fe::fe@853#dns.quad9.net
    forward-addr: 2620:fe::fe:9@443#dns.quad9.net
    forward-addr: 2620:fe::fe:9@853#dns.quad9.net
    forward-addr: 2620:fe::10@443#dns10.quad9.net
    forward-addr: 2620:fe::10@853#dns10.quad9.net
    forward-addr: 2620:fe::fe:10@443#dns10.quad9.net
    forward-addr: 2620:fe::fe:10@853#dns10.quad9.net
    forward-addr: 2620:fe::11@443#dns11.quad9.net
    forward-addr: 2620:fe::11@853#dns11.quad9.net
    forward-addr: 2620:fe::fe:11@443#dns11.quad9.net
    forward-addr: 2620:fe::fe:11@853#dns11.quad9.net
    # Cloudflare
    forward-addr: 1.1.1.1@443#cloudflare-dns.com
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@443#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
    forward-addr: 1.1.1.2@443#security.cloudflare-dns.com
    forward-addr: 1.1.1.2@853#security.cloudflare-dns.com
    forward-addr: 1.0.0.2@443#security.cloudflare-dns.com
    forward-addr: 1.0.0.2@853#security.cloudflare-dns.com
    forward-addr: 1.1.1.3@443#family.cloudflare-dns.com
    forward-addr: 1.1.1.3@853#family.cloudflare-dns.com
    forward-addr: 1.0.0.3@443#family.cloudflare-dns.com
    forward-addr: 1.0.0.3@853#family.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1111@443#cloudflare-dns.com
    forward-addr: 2606:4700:4700::1111@853#cloudflare-dns.com
    forward-addr: 2606:4700:4700::1001@443#cloudflare-dns.com
    forward-addr: 2606:4700:4700::1001@853#cloudflare-dns.com
    forward-addr: 2606:4700:4700::1112@443#security.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1112@853#security.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1002@443#security.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1113@443#family.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1113@853#family.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1003@443#family.cloudflare-dns.com
    forward-addr: 2606:4700:4700::1003@853#family.cloudflare-dns.com
    # Privacy-First Japan DNS
    forward-addr: 172.104.93.80@443#jp.tiar.app
    forward-addr: 172.104.93.80@853#jp.tiar.app
    forward-addr: 104.21.91.14@443#jp.tiarap.org
    forward-addr: 104.21.91.14@853#jp.tiarap.org
    forward-addr: 172.67.164.149@443#jp.tiarap.org
    forward-addr: 172.67.164.149@853#jp.tiarap.org
    forward-addr: 2400:8902::f03c:91ff:feda:c514@443
    forward-addr: 2400:8902::f03c:91ff:feda:c514@853
    # Privacy-First Singapore DNS
    forward-addr: 174.138.29.175@443#doh.tiar.app
    forward-addr: 174.138.29.175@853#doh.tiar.app
    forward-addr: 104.21.91.14@443#doh.tiarap.org
    forward-addr: 104.21.91.14@853#doh.tiarap.org
    forward-addr: 172.67.164.149@443#doh.tiarap.org
    forward-addr: 172.67.164.149@853#doh.tiarap.org
    forward-addr: 2400:6180:0:d0::5f6e:4001@443
    forward-addr: 2400:6180:0:d0::5f6e:4001@853
    # Mullvad
    forward-addr: 194.242.2.2@853#dns.mullvad.net
    forward-addr: 194.242.2.2@443#dns.mullvad.net
    forward-addr: 194.242.2.3@853#adblock.dns.mullvad.net
    forward-addr: 194.242.2.3@443#adblock.dns.mullvad.net
    forward-addr: 194.242.2.4@853#base.dns.mullvad.net
    forward-addr: 194.242.2.4@443#base.dns.mullvad.net
    forward-addr: 194.242.2.5@853#extended.dns.mullvad.net
    forward-addr: 194.242.2.5@443#extended.dns.mullvad.net
    forward-addr: 194.242.2.6@853#family.dns.mullvad.net
    forward-addr: 194.242.2.6@443#family.dns.mullvad.net
    forward-addr: 194.242.2.9@853#all.dns.mullvad.net
    forward-addr: 194.242.2.9@443#all.dns.mullvad.net
    forward-addr: 2a07:e340::2@853#dns.mullvad.net
    forward-addr: 2a07:e340::2@443#dns.mullvad.net
    forward-addr: 2a07:e340::3@853#adblock.dns.mullvad.net
    forward-addr: 2a07:e340::3@443#adblock.dns.mullvad.net
    forward-addr: 2a07:e340::4@853#base.dns.mullvad.net
    forward-addr: 2a07:e340::4@443#base.dns.mullvad.net
    forward-addr: 2a07:e340::5@853#extended.dns.mullvad.net
    forward-addr: 2a07:e340::5@443#extended.dns.mullvad.net
    forward-addr: 2a07:e340::6@853#familydns.mullvad.net
    forward-addr: 2a07:e340::6@443#familydns.mullvad.net
    forward-addr: 2a07:e340::9@853#all.dns.mullvad.net
    forward-addr: 2a07:e340::9@443#all.dns.mullvad.net
    # ControlD
    forward-addr: 76.76.2.0@443#p0.freedns.controld.com
    forward-addr: 76.76.2.0@853#p0.freedns.controld.com
    forward-addr: 76.76.2.1@443#p1.freedns.controld.com
    forward-addr: 76.76.2.1@853#p1.freedns.controld.com
    forward-addr: 76.76.2.2@443#p2.freedns.controld.com
    forward-addr: 76.76.2.2@853#p2.freedns.controld.com
    forward-addr: 76.76.2.3@443#p3.freedns.controld.com
    forward-addr: 76.76.2.3@853#p3.freedns.controld.com
    forward-addr: 76.76.10.0@443
    forward-addr: 76.76.10.0@853
    forward-addr: 76.76.2.11@443
    forward-addr: 76.76.2.11@853
    forward-addr: 2606:1a40::@443
    forward-addr: 2606:1a40::@853
    forward-addr: 2606:1a40:1::@443
    forward-addr: 2606:1a40:1::@853
    # dns0.eu
    forward-addr: 94.237.112.248@443#zero.dns0.eu
    forward-addr: 94.237.112.248@853#zero.dns0.eu
    forward-addr: 65.108.52.121@443#zero.dns0.eu
    forward-addr: 65.108.52.121@853#zero.dns0.eu
    # NextDNS
    forward-addr: 45.90.28.0@443#anycast.dns.nextdns.io
    forward-addr: 45.90.28.0@853#anycast.dns.nextdns.io
    forward-addr: 45.90.30.0@443#anycast.dns.nextdns.io
    forward-addr: 45.90.30.0@853#anycast.dns.nextdns.io
    forward-addr: 37.252.249.233@443#dns.nextdns.io
    forward-addr: 45.11.104.186@853#dns.nextdns.io
    forward-addr: 37.252.249.233@443#dns.nextdns.io
    forward-addr: 45.11.104.186@853#dns.nextdns.io
    # uncensoreddns
    forward-addr: 91.239.100.100@443#anycast.uncensoreddns.org
    forward-addr: 91.239.100.100@853#anycast.uncensoreddns.org
    forward-addr: 89.233.43.71@443#unicast.uncensoreddns.org
    forward-addr: 89.233.43.71@853#unicast.uncensoreddns.org
    forward-addr: 2001:67c:28a4::@443#unicast.uncensoreddns.org
    forward-addr: 2001:67c:28a4::@853#unicast.uncensoreddns.org
    forward-addr: 2a01:3a0:53:53::@443#unicast.uncensoreddns.org
    forward-addr: 2a01:3a0:53:53::@853#unicast.uncensoreddns.org
    # CleanBrowsing
    forward-addr: 185.228.168.168@443#family-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.168.168@853#family-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.169.168@443#family-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.169.168@853#family-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:1::@443#family-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:1::@853#family-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:2::@443#family-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:2::@853#family-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.168.10@443#adult-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.168.10@853#adult-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.169.11@443#adult-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.169.11@853#adult-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:1::1@443#adult-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:1::1@853#adult-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:2::1@443#adult-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:2::1@853#adult-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.168.9@443#security-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.168.9@853#security-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.169.9@443#security-filter-dns.cleanbrowsing.org
    forward-addr: 185.228.169.9@853#security-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:1::2@443#security-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:1::2@853#security-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:2::2@443#security-filter-dns.cleanbrowsing.org
    forward-addr: 2a0d:2a00:2::2@853#security-filter-dns.cleanbrowsing.org
    # Adguardhome
    forward-addr: 94.140.15.15@443#dns.adguard-dns.com
    forward-addr: 94.140.15.15@853#dns.adguard-dns.com
    forward-addr: 94.140.14.14@443#dns.adguard-dns.com
    forward-addr: 94.140.14.14@853#dns.adguard-dns.com
    forward-addr: 2a10:50c0::ad1:ff@443#dns.adguard-dns.com
    forward-addr: 2a10:50c0::ad1:ff@853#dns.adguard-dns.com
    forward-addr: 2a10:50c0::ad2:ff@443#dns.adguard-dns.com
    forward-addr: 2a10:50c0::ad2:ff@853#dns.adguard-dns.com
    forward-addr: 94.140.14.15@443#family.adguard-dns.com
    forward-addr: 94.140.14.15@853#family.adguard-dns.com
    forward-addr: 94.140.15.16@443#family.adguard-dns.com
    forward-addr: 94.140.15.16@853#family.adguard-dns.com
    forward-addr: 2a10:50c0::1:ff@443#family.adguard-dns.com
    forward-addr: 2a10:50c0::1:ff@853#family.adguard-dns.com
    forward-addr: 2a10:50c0::2:ff@443#family.adguard-dns.com
    forward-addr: 2a10:50c0::2:ff@853#family.adguard-dns.com
    forward-addr: 94.140.14.140@443#unfiltered.adguard-dns.com
    forward-addr: 94.140.14.140@853#unfiltered.adguard-dns.com
    forward-addr: 94.140.14.141@443#unfiltered.adguard-dns.com
    forward-addr: 94.140.14.141@853#unfiltered.adguard-dns.com
    forward-addr: 2a10:50c0::bad1:ff@443#unfiltered.adguard-dns.com
    forward-addr: 2a10:50c0::bad1:ff@853#unfiltered.adguard-dns.com
    forward-addr: 2a10:50c0::bad2:ff@443#unfiltered.adguard-dns.com
    forward-addr: 2a10:50c0::bad2:ff@853#unfiltered.adguard-dns.com
```
