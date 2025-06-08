{
  modulesPath,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  boot = {
    # Use predictable network interface names.
    kernelParams = ["net.ifnames=0"];
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  # https://community.hetzner.com/tutorials/install-and-configure-ntp
  networking.timeServers = ["ntp1.hetzner.de" "ntp2.hetzner.com" "ntp3.hetzner.net"];

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."30-wan" = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
    address = [
      ''${builtins.getEnv "REMOTE_IP6"}/64''
    ];
    routes = [
      {Gateway = "fe80::1";}
    ];
  };
}
