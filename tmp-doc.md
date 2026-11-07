# 0.准备工作&检查
显卡直通的前提条件是：  
* NVIDIA 独立显卡本身要具有视频输出功能  
* 机身上至少有一个连接到独立显卡的视频接口  
* 安装kvm虚拟机，具体步骤参照本博客archlinux安装或archlinux wiki

强烈建议阅读本文时参照下面几篇文章：  
[PCI_passthrough_via_OVMF_ARCHLINUX wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF_(%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)#%E7%A1%AC%E4%BB%B6%E8%A6%81%E6%B1%82)  
[Optimus MUXed 笔记本上的 NVIDIA 虚拟机显卡直通](https://lantian.pub/article/modify-computer/laptop-muxed-nvidia-passthrough.lantian/)  
[vanities/GPU-Passthrough-Arch-Linux-to-Windows10
Public](https://github.com/vanities/GPU-Passthrough-Arch-Linux-to-Windows10)  
[
KVM-GPU-Passthrough](https://github.com/BigAnteater/KVM-GPU-Passthrough)  
[Optimus笔记本虚拟机显卡直通](https://www.bwsl.wang/script/119.html)
[Linux低延遲在Windows虛擬機玩遊戲 ～ QEMU/KVM ＋ VFIO雙GPU直通 ＋ Looking Glass安裝過程](https://ivonblog.com/posts/qemu-kvm-vfio-gaming/)

# 1.1开始  
## 1.1隔离独显  
### 1.1.1引导镜像的编辑
运行 ` lspci -nn | grep NVIDIA `，获得类似如下输出,中括号里的八位是我们需要的
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106M [GeForce RTX 3060 Mobile / Max-Q] [10de:2520] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:228e] (rev a1)
```
编辑或创建`/etc/modprobe.d/vfio.conf`，ids后面写上面得到的八位，并用逗号间隔(也可以添加内核参数 `vfio-pci.ids=...`)
```
options vfio-pci ids=10de:2520,10de:228e
```
修改`/etc/mkinitcpio.conf`，在**MODULES**里增加
```
vfio_pci vfio vfio_iommu_type1 vfio_virqfd
```  
还需要确保`/etc/mkinitcpio.conf`之中有`modconf`  
之后执行`sudo mkinitcpio -P`更新initramfs  
### 1.1.2引导时内核参数的编辑
为了使iommu加载，还需要在引导选项中  
修改`/etc/default/grub`  
(注意：如果你是systemd-boot或者refind用户请自行编辑conf来应用内核参数)  
对于intel用户：
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet ... intel_iommu=on"
```
对于amd用户  
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet ... amd_iommu=on"
```
然后构建grub引导
`sudo grub-mkconfig -o /boot/grub/grub.cfg`

### 1.1.3重启后检查
运行`lspci -nnk`若输出中`Kernel driver in use`一行为`vfio-pci`则万事具备  
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106M [GeForce RTX 3060 Mobile / Max-Q] [10de:2520] (rev a1)
	DeviceName: NVIDIA Graphics Device
	Subsystem: Hewlett-Packard Company Device [103c:88d1]
	Kernel driver in use: vfio-pci
	Kernel modules: nouveau, nvidia_drm, nvidia
01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:228e] (rev a1)
	Subsystem: Hewlett-Packard Company Device [103c:88d1]
	Kernel driver in use: vfio-pci
	Kernel modules: snd_hda_intel
```

## 1.2准备一个虚拟机
之前文章已经说过了，在这不赘述了，在这里写一些可能遇到的问题  
### 1.2.1 BIOS的选择
在bios上建议选择UEFI,对显卡的支持好一些  
在**安装前**选择安装前配置，选择`概览`，`芯片组`选择`Q35`，`固件`选择`/usr/share/edk2-ovmf/x64/OVMF_CODE.fd`  
接着进入安装windows,别忘了给windows打上`virtio-win`的驱动,再去红帽的[spice-space](https://www.spice-space.org/download)下载[spice-guest-tools](https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe)
### 1.2.2 如果你已经给windows安装了上了传统legacy bios
进入windows,以管理员权限运行  
```
mbr2gpt /convert /allowfullOS
```
之后将kvm的`概览`的xml中的`os`字段改为以下模样  
```
<os>
    <type arch="x86_64" machine="pc-q35-6.2">hvm</type>
    <loader readonly="yes" type="pflash">/usr/share/edk2-ovmf/x64/OVMF_CODE.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/win10_VARS.fd</nvram>
    <boot dev="hd"/>
</os>
```
## 1.3 虚拟机上的操作
先不着急添加直通显卡，先进入虚拟机安装对应的显卡驱动，然后重启  
在虚拟机上添加`PCI主机设备`把刚刚做过手脚的gpu选择上  
不出意外的话重启你竟然发现原来丝滑的鼠标突然不能用了  
已知的解决方法：  
* 某宝购买kvm切换器，然后在 Virt-Manager 里选择添加硬件（Add Hardware） - USB 宿主设备（USB Host Device），选择你的鼠标键盘即可  
* Looking-glass或者scream,请自行参照官方文档安装配置  
* 笔记本电脑有一套外接键鼠的话直接直通这一套键鼠，linux上使用触摸板和自带键盘  

由于启用looking-glass低延迟桌面需要独立显卡有输出信号，所以你需要保持显卡外接了屏幕或者使用了显卡欺骗器

# 虚拟机性能优化  
## cpu 优化
在“CPUs”部分，将您的 CPU 型号更改为`host-passthrough`
然后打开`手动设置CPU拓扑`，保持`套接字`为`1`（这是为了让cpu能够减少内存交换的次数）  

接下来hugepage(按照wiki的来我没有成功，谨慎尝试)
1. 首先查看`cat /proc/meminfo | grep Hugetlb` 是否启用Hugepage，若Hugetlb 0kb代表没启用  
2. `sudo $EDITOR /etc/sysctl.d/99-kvm.conf`  
预留8GB RAM (1 hugepage = 2mb)给虚拟机，添加以下内容
```
vm.nr_hugepages=4096
vm.hugetlb_shm_group=48
```
3. 编辑XML,在`<memory></memory>`里添加
```
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

接下来是cpu固定，同样编辑XML,在`<vcpu></vcpu>`字段下面添加需要独占的核心
```
  <cputune>
    <vcpupin vcpu="0" cpuset="0"/>
    <vcpupin vcpu="1" cpuset="1"/>
    <vcpupin vcpu="2" cpuset="2"/>
    <vcpupin vcpu="3" cpuset="3"/>
  </cputune>
```
调整hyper-v设置，在`<features></features>`里添加
```
  <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="8191"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on"/>
      <reset state="on"/>
      <vendor_id state="on" value="123456789123"/>
      <frequencies state="on"/>
  </hyperv>
```

## io 优化 
这里提两点：
1. 进入“添加硬件”并为“VirtIO SCSI”型号的**SCSI驱动器添加控制器**  
然后然后将默认 SATA 磁盘更改为SCSI磁盘，该磁盘将绑定到所述控制器。
2. 如果你电脑的其他硬盘上有一个winodws系统你可以直接把这个硬盘给直通进来，并在启动选项里面选择它，你就不需要虚拟硬盘了！！！这样你就拥有了接近ssd原生的读写速度！

# 去虚拟化/游戏
这一节将会配置looking-glass的低延迟桌面，让windows不把kvm当虚拟机等等一些重要提升体验的配置  
### looking-glass
1. 在它的[官网](https://looking-glass.io/downloads)下载[Windows Host Binary](https://looking-glass.io/artifact/stable/host)到windows虚拟机里面并安装
2. 接下来在你的宿主机上安装looking-glass的客户端，arch用户应该`paru -S looking-glass`
3. 编辑XML,在`<device></device>`里添加
```
<devices>
  <shmem name='looking-glass'>
    <model type='ivshmem-plain'/>
    <size unit='M'>32</size>
  </shmem>
</devices>
```
4. 因为looking-glass是用过tmpfs来实现低延迟串流的，所以编辑`sudo $EDITOR /etc/tmpfiles.d/10-looking-glass.conf` 注意：`user`应当改成你的用户名！  
```
# Type       Path        Mode UID       GID Age Argument
f /dev/shm/looking-glass 0660 user    kvm -
```

### 添加解决没有音频输出的问题
1. `sudo $EDITOR /etc/libvirt/qemu.conf`,找到这一行：`user = "user"`,把双引号里的user改为你的用户名
2. 在XML`<device>`中添加
```
    <sound model="ich6">
      <codec type="micro"/>
      <audio id="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1b" function="0x0"/>
    </sound>
    <audio id="1" type="spice">
      <input mixingEngine="yes" fixedSettings="yes" voices="1" bufferLength="100">
        <settings frequency="44100" channels="2" format="s16"/>
      </input>
      <output mixingEngine="yes" fixedSettings="yes" voices="2" bufferLength="100">
        <settings frequency="44100" channels="4" format="f32"/>
      </output>
    </audio>
```

### 去虚拟化
启动windows在任务管理器的性能-cpu里面会发现`虚拟化：是`  
这个时候需要编辑XML：
```
<cpu mode='host-passthrough' check='none'>
<topology sockets='1' cores='6' threads='2'/>
<feature policy='disable' name='hypervisor'/>
</cpu>
```
首先获取你的机器信息
```
sudo dmidecode --type bios
sudo dmidecode --type baseboard
sudo dmidecode --type system
sudo dmidecode --type chassis
```
然后根据bios,baseboard,system,chassis信息对照填入vendor,manufacturer等信息，如下：
```
<sysinfo type="smbios">
    <bios>
      <entry name="vendor">AMI</entry>
    </bios>
    <system>
      <entry name="manufacturer">HP</entry>
      <entry name="product">OMEN Laptop 15-en1xxx</entry>
    </system>
    <baseBoard>
      <entry name="manufacturer">HP</entry>
      <entry name="product">88D1</entry>
      <entry name="version">75.75</entry>
      <entry name="serial">EFEA34756QWE</entry>
    </baseBoard>
    <chassis>
      <entry name="manufacturer">HP</entry>
      <entry name="version">Chassis Version</entry>
      <entry name="serial">6AD2345FF74</entry>
      <entry name="asset">Not Specified</entry>
      <entry name="sku">Not Specified</entry>
    </chassis>
    <oemStrings>
      <entry>myappname:some arbitrary data</entry>
      <entry>otherappname:more arbitrary data</entry>
    </oemStrings>
  </sysinfo>
  <os firmware="efi">
  ...
```
# 我的完整配置：
```
<domain type="kvm">
  <name>win11</name>
  <uuid>9806182e-c6cd-4855-ba84-626d953e0bdf</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/11"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">8388608</memory>
  <currentMemory unit="KiB">8388608</currentMemory>
  <vcpu placement="static">8</vcpu>
  <cputune>
    <vcpupin vcpu="0" cpuset="0"/>
    <vcpupin vcpu="1" cpuset="1"/>
    <vcpupin vcpu="2" cpuset="2"/>
    <vcpupin vcpu="3" cpuset="3"/>
    <vcpupin vcpu="4" cpuset="4"/>
    <vcpupin vcpu="5" cpuset="5"/>
    <vcpupin vcpu="6" cpuset="6"/>
    <vcpupin vcpu="7" cpuset="7"/>
  </cputune>
  <sysinfo type="smbios">
    <bios>
      <entry name="vendor">AMI</entry>
    </bios>
    <system>
      <entry name="manufacturer">HP</entry>
      <entry name="product">OMEN Laptop 15-en1xxx</entry>
    </system>
    <baseBoard>
      <entry name="manufacturer">HP</entry>
      <entry name="product">88D1</entry>
      <entry name="version">75.75</entry>
      <entry name="serial">EFEA34756QWE</entry>
    </baseBoard>
    <chassis>
      <entry name="manufacturer">HP</entry>
      <entry name="version">Chassis Version</entry>
      <entry name="serial">6AD2345FF74</entry>
      <entry name="asset">Not Specified</entry>
      <entry name="sku">Not Specified</entry>
    </chassis>
    <oemStrings>
      <entry>myappname:some arbitrary data</entry>
      <entry>otherappname:more arbitrary data</entry>
    </oemStrings>
  </sysinfo>
  <os firmware="efi">
    <type arch="x86_64" machine="pc-q35-8.0">hvm</type>
    <firmware>
      <feature enabled="no" name="enrolled-keys"/>
      <feature enabled="no" name="secure-boot"/>
    </firmware>
    <loader readonly="yes" type="pflash">/usr/share/edk2/x64/OVMF_CODE.fd</loader>
    <nvram template="/usr/share/edk2/x64/OVMF_VARS.fd">/var/lib/libvirt/qemu/nvram/win11_VARS.fd</nvram>
    <bootmenu enable="no"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="8191"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on"/>
      <reset state="on"/>
      <vendor_id state="on" value="123456789123"/>
      <frequencies state="on"/>
    </hyperv>
    <kvm>
      <hidden state="on"/>
    </kvm>
    <vmport state="off"/>
    <smm state="on"/>
    <ioapic driver="kvm"/>
  </features>
  <cpu mode="host-passthrough" check="none" migratable="on">
    <topology sockets="1" dies="1" cores="8" threads="1"/>
    <feature policy='disable' name='hypervisor'/>
  </cpu>
  <clock offset="localtime">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    <timer name="hypervclock" present="yes"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <controller type="usb" index="0" model="qemu-xhci" ports="15">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    <controller type="pci" index="0" model="pcie-root"/>
    <controller type="pci" index="1" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="1" port="0x10"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="2" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="2" port="0x11"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    <controller type="pci" index="3" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="3" port="0x12"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    <controller type="pci" index="4" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="4" port="0x13"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    <controller type="pci" index="5" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="5" port="0x14"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x4"/>
    </controller>
    <controller type="pci" index="6" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="6" port="0x15"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x5"/>
    </controller>
    <controller type="pci" index="7" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="7" port="0x16"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x6"/>
    </controller>
    <controller type="pci" index="8" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="8" port="0x17"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x7"/>
    </controller>
    <controller type="pci" index="9" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="9" port="0x18"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="10" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="10" port="0x19"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x1"/>
    </controller>
    <controller type="pci" index="11" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="11" port="0x1a"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x2"/>
    </controller>
    <controller type="pci" index="12" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="12" port="0x1b"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x3"/>
    </controller>
    <controller type="pci" index="13" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="13" port="0x1c"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x4"/>
    </controller>
    <controller type="pci" index="14" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="14" port="0x1d"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x5"/>
    </controller>
    <controller type="pci" index="15" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="15" port="0x1e"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x6"/>
    </controller>
    <controller type="pci" index="16" model="pcie-to-pci-bridge">
      <model name="pcie-pci-bridge"/>
      <address type="pci" domain="0x0000" bus="0x07" slot="0x00" function="0x0"/>
    </controller>
    <controller type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    <controller type="virtio-serial" index="0">
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </controller>
    <interface type="network">
      <mac address="52:54:00:23:03:75"/>
      <source network="default"/>
      <model type="e1000e"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
      <address type="virtio-serial" controller="0" bus="0" port="1"/>
    </channel>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <tpm model="tpm-crb">
      <backend type="emulator" version="2.0"/>
    </tpm>
    <graphics type="spice" port="-1" autoport="no">
      <listen type="address"/>
      <image compression="off"/>
    </graphics>
    <sound model="ich6">
      <codec type="micro"/>
      <audio id="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1b" function="0x0"/>
    </sound>
    <audio id="1" type="spice">
      <input mixingEngine="yes" fixedSettings="yes" voices="1" bufferLength="100">
        <settings frequency="44100" channels="2" format="s16"/>
      </input>
      <output mixingEngine="yes" fixedSettings="yes" voices="2" bufferLength="100">
        <settings frequency="44100" channels="4" format="f32"/>
      </output>
    </audio>
    <video>
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </hostdev>
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
    </hostdev>
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
      </source>
      <boot order="1"/>
      <address type="pci" domain="0x0000" bus="0x08" slot="0x00" function="0x0"/>
    </hostdev>
    <redirdev bus="usb" type="spicevmc">
      <address type="usb" bus="0" port="2"/>
    </redirdev>
    <watchdog model="itco" action="reset"/>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
    </memballoon>
    <shmem name="looking-glass">
      <model type="ivshmem-plain"/>
      <size unit="M">32</size>
      <address type="pci" domain="0x0000" bus="0x10" slot="0x01" function="0x0"/>
    </shmem>
  </devices>
</domain>
```
/etc/modprobe.d/kvm.conf
```
options iommu=pt amd_iommu=on   
options vfio-pci ids=10de:2520,10de:228e disable_vga=1
options kvm ignore_msrs=1 report_ignored_msrs=0
options vfio_iommu_type1 allow_unsafe_interrupts=1
```
