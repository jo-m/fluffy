{lib, ...}: {
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=512M"];
  };

  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };
          ESP = {
            size = "256M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          lvm_pool = {
            name = "lvm_pool";
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          # System (NixOS) & home (container storage).
          root = {
            size = "20G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };

          # Container data mounts.
          data = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/data";
              mountOptions = [
                "defaults"
              ];
            };
          };
        };
      };
    };
  };
}
