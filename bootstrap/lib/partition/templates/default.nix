{ config, pkgs, ... }:

let
  params = import ./params.nix;
  disk = params.disk;
  fsType = params.fsType or "btrfs";
  encrypt = if builtins.hasAttr "encrypt" params then params.encrypt else true;
  unlockMode = params.unlockMode or "manual"; # manual|dropbear|tpm|keyfile (partition shape only cares about dropbear)
  swapSizeMi = params.swapSize or 0;
  separateHome = params.separateHome or false;
  homeSize = params.homeSize or "20G";

  espSize = "512M";
  bootSize = "512M";

  mkFs = type: {
    type = "filesystem";
    format = type;
  };

  mkFsMnt = type: mnt: (mkFs type) // { mountpoint = mnt; };

in {
  disko.devices.disk.main = {
    device = disk;
    type = "disk";
    content = {
      type = "gpt";
      partitions =
        let
          base = {
            esp = {
              size = espSize;
              type = "EF00";
              content = mkFsMnt "vfat" "/boot/efi";
            };
            boot = {
              size = bootSize;
              type = "8300";
              content = mkFsMnt "ext4" "/boot";
            };
          };

          withSwap = if swapSizeMi > 0 then base // {
            swap = {
              size = toString swapSizeMi + "M";
              type = "8200";
              content = { type = "swap"; }; # disko uses content.type=swap
            };
          } else base;

          rootPart = {
            size = "100%";
            content = if encrypt then {
              type = "luks";
              name = "cryptroot";
              content = mkFsMnt fsType "/";
            } else (mkFsMnt fsType "/");
          };

          homePart = if separateHome then {
            # Reserve from the tail by setting root smaller would be ideal, but
            # simple approach: rely on 100% root and create home inside FS (btrfs subvol suggested).
            # For separate partition scenarios, user can provide a custom disko file.
          } else {};

        in withSwap // { root = rootPart; } // homePart;
    };
  };
}
