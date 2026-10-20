{config, ...}: {
  systemd.network.networks = {
    # Teddycloud needs to listen directly on :443, which would conflict with Caddy,
    # so we assign a separate static IP for this on the upstream interface.
    # networkd applies only the first matching unit in lexicographic order, so
    # this shadows 20-eth-lan for enp1s0 and must repeat its settings.
    "10-enp1s0" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      addresses = [
        {Address = "${config.services.foggy.teddycloud.tonieApiAddr}/24";}
      ];
    };
  };
}
