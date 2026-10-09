{
  config,
  lib,
  ...
}: let
  # foggy-stage0 imports this file without the caddy module.
  caddyBindIP =
    if config.services ? foggy && config.services.foggy ? caddy
    then config.services.foggy.caddy.bindIP
    else "";
in {
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    networks =
      # Fallback for ethernet interfaces without a more specific unit.
      {
        "20-eth-lan" = {
          matchConfig.Name = "en*";
          networkConfig = {
            DHCP = "ipv4";
            IPv6AcceptRA = true;
          };
        };
      }
      // lib.optionalAttrs (config.services ? foggy && config.services.foggy ? teddycloud) {
        # Teddycloud needs to listen directly on :443, which would conflict with Caddy,
        # so we assign a separate static IP for this on the upstream interface.
        # networkd applies only the first matching unit in lexicographic order, so
        # this shadows 20-eth-lan for enp1s0 and must repeat its settings.
        # Guarded because foggy-stage0 imports this file without the teddycloud module.
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
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      # We don't want to publish ${tonieApiAddr}, whose :443 serves teddycloud and not Caddy,
      # and also not the IPv6 addresses to which Caddy does not bind.
      addresses = false;
      workstation = true;
    };
  };

  # Instead, publish explicitly via /etc/avahi/hosts.
  # Check via `avahi-browse -avrt`.
  environment.etc."avahi/hosts" = lib.mkIf (caddyBindIP != "") {
    text = "${caddyBindIP} ${config.networking.hostName}.local\n";
  };
}
