{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.vfio;
  inherit (cfg) vm;
  pt = cfg.gpuPassthrough;
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    concatMapStrings
    concatStringsSep
    ;

  pciAddrRe = "[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\\.[0-7]";
  parseAddr =
    a:
    let
      m = builtins.match "([0-9a-f]{4}):([0-9a-f]{2}):([0-9a-f]{2})\\.([0-7])" a;
    in
    ''domain="0x${builtins.elemAt m 0}" bus="0x${builtins.elemAt m 1}" slot="0x${builtins.elemAt m 2}" function="0x${builtins.elemAt m 3}"'';

  # SMT siblings on this CPU family are (2N, 2N+1)
  threadsOf = c: [
    (2 * c)
    (2 * c + 1)
  ];
  guestThreads = lib.concatMap threadsOf vm.cpu.guestCores;
  hostThreads = lib.concatMap threadsOf vm.cpu.hostCores;
  cpuset = l: concatStringsSep "," (map toString l);

  esc = lib.escapeXML;
  smbiosXml = concatStringsSep "\n" (
    lib.mapAttrsToList (section: entries: ''
      <${section}>
      ${concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: "  <entry name=\"${esc k}\">${esc v}</entry>") entries
      )}
      </${section}>'') vm.smbios
  );

  hostdevXml = lib.optionalString pt.enable (
    concatMapStrings (d: ''
      <hostdev mode="subsystem" type="pci" managed="yes">
        <source>
          <address ${parseAddr d.address}/>
        </source>
        ${lib.optionalString (d.romfile != null) ''<rom bar="on" file="${esc d.romfile}"/>''}
      </hostdev>
    '') pt.devices
  );

  # Win10/11 drivers only; Windows setup needs vioscsi/viostor to see a virtio disk
  virtioWinIso = pkgs.runCommand "virtio-win-slim.iso" { nativeBuildInputs = [ pkgs.xorriso ]; } ''
    mkdir tree
    for d in vioscsi viostor NetKVM vioserial Balloon qxldod vioinput viorng; do
      for v in w10 w11; do
        if [ -d ${pkgs.virtio-win}/$d/$v ]; then
          mkdir -p tree/$d
          cp -rL ${pkgs.virtio-win}/$d/$v tree/$d/
        fi
      done
    done
    cp ${pkgs.virtio-win}/virtio-win-guest-tools.exe tree/
    xorriso -as mkisofs -r -J -V VIRTIO_WIN -o $out tree
  '';

  media = vm.installMedia ++ lib.optional vm.virtioWin.enable (toString virtioWinIso);
  cdromXml = concatStringsSep "\n" (
    lib.imap0 (i: path: ''
      <disk type="file" device="cdrom">
        <driver name="qemu" type="raw"/>
        <source file="${esc path}"/>
        <target dev="${builtins.elemAt [ "sdb" "sdc" "sdd" "sde" ] i}" bus="sata"/>
        <readonly/>
        ${lib.optionalString (i == 0 && vm.installMedia != [ ]) ''<boot order="2"/>''}
      </disk>'') media
  );

  domainXml = pkgs.writeText "${vm.name}.xml" ''
    <domain type="kvm">
      <name>${esc vm.name}</name>
      <uuid>${vm.uuid}</uuid>
      <memory unit="MiB">${toString vm.memoryMiB}</memory>
      <currentMemory unit="MiB">${toString vm.memoryMiB}</currentMemory>
      ${lib.optionalString cfg.hugepages.enable ''
        <memoryBacking>
          <hugepages/>
        </memoryBacking>''}
      <vcpu placement="static">${toString (builtins.length guestThreads)}</vcpu>
      <iothreads>1</iothreads>
      <cputune>
      ${concatStringsSep "\n" (
        lib.imap0 (i: t: ''<vcpupin vcpu="${toString i}" cpuset="${toString t}"/>'') guestThreads
      )}
        <emulatorpin cpuset="${cpuset hostThreads}"/>
        <iothreadpin iothread="1" cpuset="${cpuset hostThreads}"/>
      </cputune>
      ${lib.optionalString vm.hideHypervisor ''
        <sysinfo type="smbios">
        ${smbiosXml}
        </sysinfo>''}
      <os firmware="efi">
        <type arch="x86_64" machine="${vm.machine}">hvm</type>
        <firmware>
          <feature enabled="no" name="enrolled-keys"/>
          <feature enabled="no" name="secure-boot"/>
        </firmware>
        <bootmenu enable="no"/>
        ${lib.optionalString vm.hideHypervisor ''<smbios mode="sysinfo"/>''}
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
          <vendor_id state="on" value="${esc vm.hypervVendorId}"/>
          <frequencies state="on"/>
        </hyperv>
        ${lib.optionalString vm.hideHypervisor ''
          <kvm>
            <hidden state="on"/>
          </kvm>''}
        <vmport state="off"/>
        <smm state="on"/>
        <ioapic driver="kvm"/>
      </features>
      <cpu mode="host-passthrough" check="none" migratable="on">
        <topology sockets="1" dies="1" cores="${toString (builtins.length vm.cpu.guestCores)}" threads="2"/>
        ${lib.optionalString vm.hideHypervisor ''<feature policy="disable" name="hypervisor"/>''}
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
        <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
        <disk type="file" device="disk">
          <driver name="qemu" type="${vm.disk.format}" cache="none" io="native" discard="unmap"/>
          <source file="${esc vm.disk.path}"/>
          <target dev="sda" bus="${vm.disk.bus}"/>
          <boot order="1"/>
        </disk>
        ${cdromXml}
        <controller type="scsi" index="0" model="virtio-scsi">
          <driver queues="4" iothread="1"/>
        </controller>
        <controller type="usb" index="0" model="qemu-xhci" ports="15"/>
        <interface type="network">
          <mac address="${vm.network.mac}"/>
          <source network="${esc vm.network.source}"/>
          <model type="${vm.network.model}"/>
        </interface>
        <channel type="spicevmc">
          <target type="virtio" name="com.redhat.spice.0"/>
        </channel>
        <input type="mouse" bus="ps2"/>
        <input type="keyboard" bus="ps2"/>
        <tpm model="tpm-crb">
          <backend type="emulator" version="2.0"/>
        </tpm>
        <graphics type="spice" port="${toString vm.spicePort}" autoport="no">
          <listen type="address" address="127.0.0.1"/>
          <image compression="off"/>
        </graphics>
        <sound model="ich6">
          <audio id="1"/>
        </sound>
        <audio id="1" type="spice"/>
        <video>
          ${
            if vm.emulatedVideo || !pt.enable then
              ''<model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1" primary="yes"/>''
            else
              ''<model type="none"/>''
          }
        </video>
        ${hostdevXml}
        <watchdog model="itco" action="reset"/>
        <memballoon model="none"/>
        ${lib.optionalString cfg.lookingGlass.enable ''
          <shmem name="looking-glass">
            <model type="ivshmem-plain"/>
            <size unit="M">${toString cfg.lookingGlass.sizeMiB}</size>
          </shmem>''}
      </devices>
    </domain>
  '';
in
{
  imports = [ ../options.nix ];

  options.modules.vfio = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "VM host optimizations: libvirt domain generated from Nix (CPU pinning, Hyper-V enlightenments, virtio-scsi, TPM), kvm ignore_msrs, Looking Glass shm, optional hugepages. Independent of GPU passthrough.";
    };

    gpuPassthrough = {
      enable = mkEnableOption "dGPU passthrough: early vfio-pci binding, IOMMU kernel params, driver blacklist, hostdev entries in the domain (the host loses the dGPU for that boot)";

      cpuVendor = mkOption {
        type = types.enum [
          "amd"
          "intel"
        ];
        default = "amd";
        description = "Selects the <vendor>_iommu=on kernel parameter.";
      };

      devices = mkOption {
        default = [ ];
        description = "PCI functions handed to vfio-pci at boot and passed through to the VM. Pass only the dGPU and its audio function; the whole IOMMU group must be free of host devices.";
        type = types.listOf (
          types.submodule {
            options = {
              id = mkOption {
                type = types.strMatching "[0-9a-f]{4}:[0-9a-f]{4}";
                example = "10de:2520";
                description = "vendor:device from lspci -nn.";
              };
              address = mkOption {
                type = types.strMatching pciAddrRe;
                example = "0000:01:00.0";
                description = "Full PCI address (domain:bus:slot.function).";
              };
              romfile = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional vBIOS ROM path; some laptop dGPUs need a patched ROM to initialise in the guest.";
              };
            };
          }
        );
      };
    };

    domainXml = mkOption {
      type = types.package;
      readOnly = true;
      internal = true;
      default = domainXml;
      description = "Generated libvirt domain XML, exposed for validation.";
    };

    kvm.ignoreMsrs = mkOption {
      type = types.bool;
      default = true;
      description = "kvm ignore_msrs=1 report_ignored_msrs=0: stops Windows guests from BSODing on unhandled MSR reads. Applies to every guest on the host.";
    };

    kvm.allowUnsafeInterrupts = mkOption {
      type = types.bool;
      default = false;
      description = "vfio_iommu_type1 allow_unsafe_interrupts=1 (only with gpuPassthrough). Only needed without interrupt remapping (AMD-Vi normally has it); weakens isolation.";
    };

    hugepages = {
      enable = mkEnableOption "2 MiB hugepage backing for the VM (reserved via vm.nr_hugepages, taken from host RAM for the whole boot)";
      count = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Number of 2 MiB pages; null derives memoryMiB / 2.";
      };
    };

    lookingGlass = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "ivshmem device in the domain plus /dev/shm/looking-glass owned by mainUser.";
      };
      sizeMiB = mkOption {
        type = types.ints.positive;
        default = 64;
        description = "ivshmem size; B7 needs >= 32 MiB for 1080p SDR, 64 MiB leaves headroom for 1440p/HDR. Must be a power of two.";
      };
      group = mkOption {
        type = types.str;
        default = "qemu-libvirtd";
        description = "Group on the shm file; matches the user libvirt runs QEMU as when runAsRoot = false (root ignores it).";
      };
    };

    vm = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Define the libvirt domain from Nix at every boot (overwrites edits made in virt-manager).";
      };
      name = mkOption {
        type = types.str;
        default = "win11";
        description = "Domain name.";
      };
      uuid = mkOption {
        type = types.strMatching "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
        default = "9806182e-c6cd-4855-ba84-626d953e0bdf";
        description = "Fixed so a re-define updates the existing domain; a same-name domain with another UUID makes the define unit fail.";
      };
      machine = mkOption {
        type = types.str;
        default = "q35";
        description = "QEMU machine type; the unversioned alias follows the installed QEMU.";
      };
      memoryMiB = mkOption {
        type = types.ints.positive;
        default = 6144;
        description = "Guest RAM. Keep well under half of host RAM on 16 GB-class machines.";
      };
      cpu = {
        guestCores = mkOption {
          type = types.listOf types.ints.unsigned;
          default = [
            4
            5
            6
            7
          ];
          description = "Physical cores given to the guest; both SMT threads of each (2N, 2N+1) are pinned, so vcpus = 2 * length.";
        };
        hostCores = mkOption {
          type = types.listOf types.ints.unsigned;
          default = [
            0
            1
            2
            3
          ];
          description = "Physical cores for QEMU emulator and iothread; must not overlap guestCores.";
        };
      };
      disk = {
        path = mkOption {
          type = types.str;
          default = "/var/lib/libvirt/images/win11.qcow2";
          description = "Existing disk image; never created or moved by this module.";
        };
        format = mkOption {
          type = types.enum [
            "qcow2"
            "raw"
          ];
          default = "qcow2";
          description = "Disk image format.";
        };
        bus = mkOption {
          type = types.enum [
            "scsi"
            "sata"
          ];
          default = "scsi";
          description = "scsi = virtio-scsi + iothread (guest needs vioscsi at install time); sata works with an existing image that has no virtio driver.";
        };
        sizeGiB = mkOption {
          type = types.nullOr types.ints.positive;
          default = null;
          description = "Create a sparse image of this size at boot if path does not exist; null never creates one.";
        };
      };
      installMedia = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = "ISO paths attached as read-only SATA CD-ROMs (max 3 with virtioWin, 4 without); the first one boots after an empty disk.";
      };
      virtioWin.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Attach a slim virtio-win driver ISO built from nixpkgs (Win10/11 drivers); load vioscsi/viostor from it in Windows setup.";
      };
      network = {
        source = mkOption {
          type = types.str;
          default = "default";
          description = "libvirt network name.";
        };
        model = mkOption {
          type = types.enum [
            "e1000e"
            "virtio"
          ];
          default = "e1000e";
          description = "e1000e works without extra drivers; virtio needs virtio-win in the guest.";
        };
        mac = mkOption {
          type = types.strMatching "([0-9a-f]{2}:){5}[0-9a-f]{2}";
          default = "52:54:00:23:03:75";
          description = "Fixed so Windows does not see a new NIC at every define.";
        };
      };
      spicePort = mkOption {
        type = types.port;
        default = 5900;
        description = "Loopback SPICE port; the Looking Glass client uses 127.0.0.1:5900 for input and audio.";
      };
      emulatedVideo = mkOption {
        type = types.bool;
        default = true;
        description = "Keep a QXL adapter next to the passed-through dGPU; false removes it (no console until the NVIDIA driver is up). Always on without gpuPassthrough.";
      };
      hideHypervisor = mkOption {
        type = types.bool;
        default = true;
        description = "Clear the CPUID hypervisor bit, hide KVM and apply SMBIOS strings, for guests/anti-cheat that refuse VMs.";
      };
      hypervVendorId = mkOption {
        type = types.strMatching ".{1,12}";
        default = "AuthenticAMD";
        description = "Hyper-V vendor_id string (max 12 chars).";
      };
      smbios = mkOption {
        type = types.attrsOf (types.attrsOf types.str);
        default = {
          bios.vendor = "American Megatrends Inc.";
          system = {
            manufacturer = "To Be Filled By O.E.M.";
            product = "To Be Filled By O.E.M.";
          };
          baseBoard = {
            manufacturer = "To Be Filled By O.E.M.";
            product = "To Be Filled By O.E.M.";
          };
          chassis.manufacturer = "To Be Filled By O.E.M.";
        };
        description = "SMBIOS sysinfo sections (bios, system, baseBoard, chassis) as attrsets of entry name to value. Serial numbers are intentionally not set by default.";
      };
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = config.modules.virtualisation.libvirtd.enable;
          message = "modules.vfio needs modules.virtualisation.libvirtd.enable (libvirtd, swtpm, Looking Glass client).";
        }
        {
          assertion = vm.cpu.guestCores != [ ] && vm.cpu.hostCores != [ ];
          message = "modules.vfio.vm.cpu.{guestCores,hostCores} must be non-empty.";
        }
        {
          assertion = lib.intersectLists vm.cpu.guestCores vm.cpu.hostCores == [ ];
          message = "modules.vfio.vm.cpu.guestCores and hostCores overlap.";
        }
        {
          assertion = builtins.length media <= 4;
          message = "modules.vfio.vm: at most 4 CD-ROMs (installMedia plus the virtio-win ISO).";
        }
        {
          assertion = lib.mod vm.memoryMiB 2 == 0;
          message = "modules.vfio.vm.memoryMiB must be even (2 MiB hugepages).";
        }
      ];

      boot.extraModprobeConfig = lib.optionalString cfg.kvm.ignoreMsrs ''
        options kvm ignore_msrs=1 report_ignored_msrs=0
      '';

      # plain assignment beats performance.nix's mkDefault 0
      boot.kernel.sysctl = mkIf cfg.hugepages.enable {
        "vm.nr_hugepages" = if cfg.hugepages.count != null then cfg.hugepages.count else vm.memoryMiB / 2;
      };

      systemd.tmpfiles.rules = lib.optional cfg.lookingGlass.enable "f /dev/shm/looking-glass 0660 ${config.mainUser} ${cfg.lookingGlass.group} -";

      systemd.services."libvirt-disk-${vm.name}" = mkIf (vm.enable && vm.disk.sizeGiB != null) {
        description = "Create disk image for libvirt domain ${vm.name} if missing";
        wantedBy = [ "multi-user.target" ];
        before = [ "libvirt-define-${vm.name}.service" ];
        unitConfig.ConditionPathExists = "!${vm.disk.path}";
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${dirOf vm.disk.path}";
          ExecStart = "${config.virtualisation.libvirtd.qemu.package}/bin/qemu-img create -f ${vm.disk.format} ${vm.disk.path} ${toString vm.disk.sizeGiB}G";
        };
      };

      systemd.services."libvirt-define-${vm.name}" = mkIf vm.enable {
        description = "Define libvirt domain ${vm.name} from Nix";
        wantedBy = [ "multi-user.target" ];
        after = [ "libvirtd.service" ];
        requires = [ "libvirtd.service" ];
        restartTriggers = [ domainXml ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.virtualisation.libvirtd.package}/bin/virsh -c qemu:///system define ${domainXml}";
        };
      };
    })

    (mkIf (cfg.enable && pt.enable) {
      assertions = [
        {
          assertion = pt.devices != [ ];
          message = "modules.vfio.gpuPassthrough.devices must list the dGPU and its audio function.";
        }
        {
          assertion = !((config.modules.nvidia or { }).enable or false);
          message = "modules.vfio.gpuPassthrough claims the NVIDIA dGPU; set modules.nvidia.enable = false in the same configuration.";
        }
      ];

      boot = {
        kernelParams = [
          "${pt.cpuVendor}_iommu=on"
          "iommu=pt"
          "vfio-pci.ids=${concatStringsSep "," (map (d: d.id) pt.devices)}"
        ];
        # vfio-pci must be in the initrd to claim the card before any GPU driver
        initrd.kernelModules = [
          "vfio_pci"
          "vfio"
          "vfio_iommu_type1"
        ];
        blacklistedKernelModules = [
          "nouveau"
          "nvidia"
          "nvidia_drm"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidiafb"
        ];
        extraModprobeConfig = lib.optionalString cfg.kvm.allowUnsafeInterrupts ''
          options vfio_iommu_type1 allow_unsafe_interrupts=1
        '';
      };
    })
  ];
}
