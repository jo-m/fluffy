{
  config,
  lib,
  ...
}: let
  cfg = config.services.fluffy.wireguard;
in {
  options.services.fluffy.wireguard = {
    iface = lib.mkOption {
      type = lib.types.str;
      description = "Name of the WireGuard interface towards foggy";
      default = "wg-foggy";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "fluffy's wg address";
      default = "10.99.0.1";
    };

    peerAddress = lib.mkOption {
      type = lib.types.str;
      description = "foggy's wg address";
      default = "10.99.0.2";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      description = "UDP port the tunnel listens on";
      # Use something different than the wg default (51820).
      # Don't forget to open on Hetzner firewall.
      default = 39277;
    };
  };

  config = {
    sops.secrets."wireguard/private-key" = {};
    sops.templates.wg-private-key.content = config.sops.placeholder."wireguard/private-key";
    sops.templates.wg-private-key.owner = "systemd-network";
    # The rendered unit only references the key file, so restart the tunnel explicitly when the key changes.
    sops.secrets."wireguard/private-key".restartUnits = ["wireguard-${cfg.iface}.service"];

    sops.secrets."wireguard/foggy-pubkey_unencrypted" = {};
    sops.templates.wg-peer-public-key.content = config.sops.placeholder."wireguard/foggy-pubkey_unencrypted";
    sops.templates.wg-peer-public-key.owner = "systemd-network";
    # The rendered unit only references the key file, so restart the tunnel explicitly when the key changes.
    sops.secrets."wireguard/foggy-pubkey_unencrypted".restartUnits = ["wireguard-${cfg.iface}.service"];

    # Secrets are currently installed by the activation script, which runs
    # before any service. If userborn/systemd-sysusers is ever enabled,
    # sops-nix switches to a boot-time unit without ordering guarantees, so
    # make the dependency explicit.
    systemd.services."wireguard-${cfg.iface}".after = ["sops-install-secrets.service"];

    networking.firewall.allowedUDPPorts = [cfg.listenPort];

    systemd.network = {
      enable = true;

      networks."50-${cfg.iface}" = {
        matchConfig.Name = "${cfg.iface}";
        address = [
          "${cfg.address}/24"
        ];
      };

      netdevs."50-${cfg.iface}" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "${cfg.iface}";
        };

        wireguardConfig = {
          ListenPort = cfg.listenPort;

          # ensure file is readable by `systemd-network` user
          PrivateKeyFile = config.sops.templates.wg-private-key.path;

          # # To automatically create routes for everything in AllowedIPs,
          # # add RouteTable=main
          # RouteTable = "main";

          # # FirewallMark marks all packets send and received by wg0
          # # with the number 42, which can be used to define policy rules on these packets.
          # FirewallMark = 42;
        };
        wireguardPeers = [
          {
            PublicKeyFile = config.sops.templates.wg-peer-public-key.path;
            AllowedIPs = ["${cfg.peerAddress}/32"];
            # No endpoint: peer dials in from behind NAT.
          }
        ];
      };
    };
  };
}
