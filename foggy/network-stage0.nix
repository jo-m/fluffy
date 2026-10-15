{
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    networks = {
      # Fallback for ethernet interfaces without a more specific unit.
      "20-eth-lan" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
      };
    };
  };
}
