{modulesPath, ...}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  boot = {
    # use predictable network interface names (eth0)
    kernelParams = ["net.ifnames=0"];
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
}
