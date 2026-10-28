{
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.drives;

  zfsModes = {
    zfs = "";
    z0 = "";
    stripe = "";
    z1 = "raidz1";
    raidz1 = "raidz1";
    raidz = "raidz";
    z2 = "raidz2";
    raidz2 = "raidz2";
    z3 = "raidz3";
    raidz3 = "raidz3";
    mirror = "mirror";
  };

  plainTypes = [
    "ext4"
    "btrfs"
    "xfs"
    "vfat"
    "f2fs"
    "exfat"
    "ntfs"
    "bcachefs"
  ];

  isZfs = type: builtins.hasAttr (lib.toLower type) zfsModes;

  driveName = i: drive:
    if drive.name != null
    then drive.name
    else "drive${toString i}";

  poolName = i: drive:
    if drive.pool != null
    then drive.pool
    else driveName i drive;

  esp = {
    size = "512M";
    type = "EF00";
    content = {
      type = "filesystem";
      format = "vfat";
      mountpoint = "/boot";
      mountOptions = ["fmask=0077" "dmask=0077"];
    };
  };

  mkPlain = i: drive: let
    type = lib.toLower drive.type;
    name = driveName i drive;
    root = drive.mount == "/";
    partition =
      if root
      then "root"
      else "data";
  in {
    disk.${name} = {
      type = "disk";
      device = builtins.head drive.disks;
      content = {
        type = "gpt";
        partitions =
          lib.optionalAttrs root {
            ESP = esp;
          }
          // {
            ${partition} = {
              size = "100%";
              content = {
                type = "filesystem";
                format = type;
                mountpoint = drive.mount;
              };
            };
          };
      };
    };
    zpool = {};
  };

  mkZfs = i: drive: let
    type = lib.toLower drive.type;
    name = driveName i drive;
    pool = poolName i drive;
    root = drive.mount == "/";
    mkDisk = j: device: {
      disk."${name}_${toString j}" = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions =
            lib.optionalAttrs (root && j == 0) {
              ESP = esp;
            }
            // {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  inherit pool;
                };
              };
            };
        };
      };
    };
    entries = lib.imap0 mkDisk drive.disks;
  in {
    disk = builtins.foldl' (acc: entry: acc // entry.disk) {} entries;
    zpool.${pool} = {
      type = "zpool";
      mode = zfsModes.${type};
      datasets.root = {
        type = "zfs_fs";
        mountpoint = drive.mount;
        options.mountpoint = "legacy";
      };
    };
  };

  mkEntry = i: drive:
    if isZfs drive.type
    then mkZfs i drive
    else mkPlain i drive;

  entries = lib.imap0 mkEntry cfg;

  disks = builtins.foldl' (acc: entry: acc // entry.disk) {} entries;
  zpools = builtins.foldl' (acc: entry: acc // entry.zpool) {} entries;

  allDisks = lib.concatMap (drive: drive.disks) cfg;
  zfsPools = lib.imap0 (i: drive:
    if isZfs drive.type
    then poolName i drive
    else null)
  cfg;
  usedPools = builtins.filter (pool: pool != null) zfsPools;
in {
  imports = [inputs.disko.nixosModules.disko];

  options.drives = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        disks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          example = ["/dev/disk/by-id/nvme-..."];
          description = "Block devices backing this disk or ZFS array.";
        };

        type = lib.mkOption {
          type = lib.types.str;
          example = "ext4";
          description = ''
            Filesystem type for single-disk entries (`ext4`, `btrfs`, `xfs`,
            `vfat`, `f2fs`, `exfat`, `ntfs`, `bcachefs`), or a ZFS mode
            (`z1`, `z2`, `z3`, `mirror`, `stripe`).
          '';
        };

        mount = lib.mkOption {
          type = lib.types.str;
          example = "/";
          description = "Mount point for the filesystem or ZFS dataset.";
        };

        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "main";
          description = ''
            Disk/array name used by `disko-install --disk` and as the default
            ZFS pool name. Defaults to `drive<index>`. ZFS entries append
            `_<disk-index>` to each physical disk (`tank_0`, `tank_1`, ...).
          '';
        };

        pool = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "tank";
          description = "ZFS pool name. Defaults to the entry name.";
        };

        encryptionKeys = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              device = lib.mkOption {
                type = lib.types.path;
                description = "Block device path (e.g. /dev/disk/by-uuid/...)";
              };
              keyName = lib.mkOption {
                type = lib.types.str;
                description = "Name of the sops secret containing the LUKS key";
              };
              fallbackToPassword = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Allow password fallback if the key fails";
              };
            };
          });
          default = [];
          description = ''
            List of LUKS encryption keys. If non-empty, the `luksKey` and
            `usbLuksKey` modules are enabled so the key can be loaded from a USB
            pendrive during early boot.
          '';
        };
      };
    });
    default = [];
    description = ''
      Declarative disk layout rendered into `disko.devices`.

      Entries with a ZFS mode use every listed disk for one pool. Other entries
      must list exactly one disk. The entry mounted at `/` gets an ESP at
      `/boot`. Do not also import generated `fileSystems` for these mounts.

      **Encryption**: add `encryptionKeys` with `device`, `keyName` (sops secret
      name) and optionally `fallbackToPassword`. The `usb-luks-key` script will
      automatically look for a USB drive with label `LUKS-KEY` (configurable via
      `usbLuksKey.label`) and load the key at early boot.
    '';
  };

  config = lib.mkIf (cfg != []) {
    disko.devices = {
      disk = disks;
      zpool = zpools;
    };

    luksKey.enable = cfg.encryptionKeys != [];
    luksKey.devices = builtins.listToAttrs (lib.imap0 (i: k: {
        name = "key${toString i}";
        value = {
          device = k.device;
          keyName = k.keyName;
          fallbackToPassword = k.fallbackToPassword;
        };
      })
      cfg.encryptionKeys);
    # normalise each drive's encryptionKeys
    normalizedEncKeys = lib.concatMap (driveIdx: drive:
      let
        disks = drive.disks;
        rawKeys = drive.encryptionKeys;
        keyCount = builtins.length rawKeys;
        normEntry i =
          if builtins.isString rawKeys[i] then
            { device = null; keyName = rawKeys[i]; fallbackToPassword = true; }
          else
            { device = rawKeys[i].device // null; keyName = rawKeys[i].keyName; fallbackToPassword = rawKeys[i].fallbackToPassword // true; };
        autoDev = dIdx: d:
          if builtins.hasAttr (lib.toLower drive.type) zfsModes then
            if drive.mount == "" && dIdx == 0 then "${d}-part2"
            else "${d}-part1"
          else
            if drive.mount == "" then "${d}-part2"
            else "${d}-part1";
      in
      if keyCount == 0 then []
      else lib.imap0 (diskIdx: disk:
        let
          keyIdx = diskIdx % keyCount;
          nk = normEntry keyIdx;
          dev = if nk.device != null then nk.device else autoDev driveIdx diskIdx;
        in
        {
          name = "key${toString driveIdx}-${toString diskIdx}";
          value = {
            device = dev;
            keyName = nk.keyName;
            fallbackToPassword = nk.fallbackToPassword;
          };
        }) disks) cfg;

    luksKey.enable = builtins.any (drive: builtins.length drive.encryptionKeys > 0) cfg;
    usbLuksKey.enable = builtins.any (drive: builtins.length drive.encryptionKeys > 0) cfg;
    luksKey.devices = builtins.listToAttrs normalizedEncKeys;

    assertions = [
      {
        assertion = lib.all (drive: drive.disks != []) cfg;
        message = "drives: every entry must list at least one disk";
      }
      {
        assertion =
          lib.all
          (drive:
            isZfs drive.type
            || builtins.elem (lib.toLower drive.type) plainTypes)
          cfg;
        message = "drives: unsupported type; use a plain filesystem, z1/z2/z3, mirror, stripe, or raidz";
      }
      {
        assertion =
          lib.all
          (drive:
            isZfs drive.type
            || builtins.length drive.disks == 1)
          cfg;
        message = "drives: non-ZFS entries must use exactly one disk";
      }
      {
        assertion = builtins.length (lib.unique allDisks) == builtins.length allDisks;
        message = "drives: the same disk is listed more than once";
      }
      {
        assertion =
          builtins.length (lib.unique (map (drive: drive.mount) cfg))
          == builtins.length cfg;
        message = "drives: mount points must be unique";
      }
      {
        assertion = builtins.length (lib.unique usedPools) == builtins.length usedPools;
        message = "drives: ZFS pool names must be unique";
      }
    ];
  };
}
