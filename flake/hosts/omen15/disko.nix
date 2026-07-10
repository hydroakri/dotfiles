{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SK_hynix_PC711_HFS512GDE9X073N_CJ12N693212102O1U";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              priority = 1;
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                device = "/dev/disk/by-uuid/CB20-8853";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            root = {
              size = "100%";
              priority = 2;
              content = {
                type = "btrfs";
                device = "/dev/disk/by-uuid/4c72b10f-9921-4cf1-9038-2ca203dcee31";
                mountpoint = "/";
                mountOptions = [
                  "rw"
                  "ssd"
                  "space_cache=v2"
                  "noatime"
                  "commit=60"
                  "compress=zstd:3"
                  "discard=async"
                ];
                subvolumes = {
                  "nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "rw"
                      "ssd"
                      "space_cache=v2"
                      "noatime"
                      "commit=60"
                      "compress=zstd:3"
                      "discard=async"
                      "nosuid"
                      "nodev"
                    ];
                  };
                  "home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "rw"
                      "ssd"
                      "space_cache=v2"
                      "noatime"
                      "commit=60"
                      "compress=zstd:3"
                      "discard=async"
                      "nosuid"
                      "nodev"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
