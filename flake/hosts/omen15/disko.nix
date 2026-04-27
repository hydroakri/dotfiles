{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNX0T523196R";
        content = {
          type = "gpt";
          partitions = {
            root = {
              size = "232.6G";
              priority = 1;
              content = {
                type = "btrfs";
                device = "/dev/disk/by-uuid/fea890b4-cc85-476c-9f53-d988b156d514";
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "rw"
                      "relatime"
                      "ssd"
                      "space_cache=v2"
                      "noatime"
                      "nodiratime"
                      "commit=60"
                      "compress=zstd:3"
                      "discard=async"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "rw"
                      "relatime"
                      "ssd"
                      "space_cache=v2"
                      "noatime"
                      "nodiratime"
                      "commit=60"
                      "compress=zstd:3"
                      "discard=async"
                      "autodefrag"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "rw"
                      "relatime"
                      "ssd"
                      "space_cache=v2"
                      "noatime"
                      "nodiratime"
                      "commit=60"
                      "compress=zstd:3"
                      "discard=async"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "rw"
                      "relatime"
                      "ssd"
                      "space_cache=v2"
                      "noatime"
                      "nodiratime"
                      "commit=60"
                      "compress=zstd:3"
                      "discard=async"
                    ];
                  };
                };
              };
            };
            ESP = {
              size = "512M";
              priority = 2;
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                device = "/dev/disk/by-uuid/5652-348E";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            MSR = {
              size = "16M";
              priority = 3;
            };
            Windows = {
              size = "232G";
              priority = 4;
            };
            WinRE = {
              size = "650M";
              priority = 5;
            };
          };
        };
      };
      steam = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SK_hynix_PC711_HFS512GDE9X073N_CJ12N693212102O1U";
        content = {
          type = "gpt";
          partitions = {
            vfat-placeholder = {
              size = "819M";
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                device = "/dev/disk/by-uuid/B15C-D90D";
              };
            };
            steam-linux = {
              size = "376.9G";
              priority = 2;
              content = {
                type = "btrfs";
                device = "/dev/disk/by-uuid/47f2fc2f-c4b1-49b4-b2d1-a147c59aa44e";
                mountpoint = "/steam-linux";
                mountOptions = [
                  "rw"
                  "relatime"
                  "ssd"
                  "space_cache=v2"
                  "noatime"
                  "nodiratime"
                  "commit=60"
                  "compress=zstd:3"
                  "discard=async"
                  "autodefrag"
                ];
              };
            };
            ext4-placeholder = {
              size = "100%";
              priority = 3;
              content = {
                type = "filesystem";
                format = "ext4";
                device = "/dev/disk/by-uuid/100c34fb-0081-49f5-b98f-4098e1b485e6";
              };
            };
          };
        };
      };
    };
  };
}
