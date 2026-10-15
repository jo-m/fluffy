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

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      # We don't want to publish teddycloud's API address, whose :443 serves
      # teddycloud and not Caddy, and also not the IPv6 addresses to which
      # Caddy does not bind.
      addresses = false;
      workstation = true;
    };
  };

  # Instead, publish explicitly via /etc/avahi/hosts.
  # Check via `avahi-browse -avrt`.
  environment.etc."avahi/hosts" = {
    text = "${config.services.foggy.caddy.bindIP} ${config.networking.hostName}.local\n";
  };
}
