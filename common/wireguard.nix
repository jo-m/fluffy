{
  config,
  lib,
  ...
}: let
  cfg = config.services.wireguard;
in {
  options.services.wireguard = {
    iface = lib.mkOption {
      type = lib.types.str;
      description = "Name of the WireGuard interface towards the peer";
      default = "wg-foggy";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "This host's address in the tunnel";
      example = "10.99.0.1";
    };

    peer-address = lib.mkOption {
      type = lib.types.str;
      description = "The peer's address in the tunnel";
      example = "10.99.0.2";
    };

    peer-public-key-secret = lib.mkOption {
      type = lib.types.str;
      description = "Name of the sops secret holding the peer's public key";
      example = "wireguard/foggy-pubkey_unencrypted";
    };

    listen-port = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      description = ''
        UDP port the tunnel listens on. Leave null when dialing out.
      '';
      default = null;
    };

    peer-endpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = ''
        Public host:port at which the peer's tunnel endpoint can be reached.
      '';
      default = null;
    };
  };

  config = {
    sops.secrets."wireguard/private-key" = {
      # The rendered unit only references the key file, so restart the tunnel explicitly when the key changes.
      restartUnits = ["wireguard-${cfg.iface}.service"];
    };
    sops.templates.wg-private-key.content = config.sops.placeholder."wireguard/private-key";
    sops.templates.wg-private-key.owner = "systemd-network";

    sops.secrets.${cfg.peer-public-key-secret} = {
      # The rendered unit only references the key file, so restart the tunnel explicitly when the key changes.
      restartUnits = ["wireguard-${cfg.iface}.service"];
    };
    sops.templates.wg-peer-public-key.content = config.sops.placeholder.${cfg.peer-public-key-secret};
    sops.templates.wg-peer-public-key.owner = "systemd-network";

    # Secrets are currently installed by the activation script, which runs
    # before any service. If userborn/systemd-sysusers is ever enabled,
    # sops-nix switches to a boot-time unit without ordering guarantees, so
    # make the dependency explicit.
    systemd.services."wireguard-${cfg.iface}".after = ["sops-install-secrets.service"];

    networking.firewall.allowedUDPPorts = lib.optional (cfg.listen-port != null) cfg.listen-port;

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

        wireguardConfig =
          {
            # ensure file is readable by `systemd-network` user
            PrivateKeyFile = config.sops.templates.wg-private-key.path;
          }
          // lib.optionalAttrs (cfg.listen-port != null) {
            ListenPort = cfg.listen-port;
          };

        wireguardPeers = [
          ({
              PublicKeyFile = config.sops.templates.wg-peer-public-key.path;
              AllowedIPs = ["${cfg.peer-address}/32"];
            }
            // lib.optionalAttrs (cfg.peer-endpoint != null) {
              Endpoint = cfg.peer-endpoint;
              # Keepalive holds the NAT mapping open.
              PersistentKeepalive = 25;
            })
        ];
      };
    };
  };
}
