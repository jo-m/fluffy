{
  config,
  lib,
  ...
}: let
  cfg = config.services.foggy.wireguard;
in {
  options.services.foggy.wireguard = {
    iface = lib.mkOption {
      type = lib.types.str;
      description = "Name of the WireGuard interface towards fluffy";
      default = "wg-foggy";
    };

    address = lib.mkOption {
      type = lib.types.str;
      description = "foggy's wg address";
      default = "10.99.0.2";
    };

    peerAddress = lib.mkOption {
      type = lib.types.str;
      description = "fluffy's wg address";
      default = "10.99.0.1";
    };

    peerEndpoint = lib.mkOption {
      type = lib.types.str;
      description = "Public host:port at which fluffy's tunnel endpoint can be reached, i.e. its public domain and listenPort";
      # Domain of the Hetzner server, provided by direnv from the encrypted
      # ENV section of secrets-fluffy.yaml (see .envrc).
      default = "${builtins.getEnv "REMOTE_DOMAIN"}:39277";
    };
  };

  config = {
    sops.secrets."wireguard/private-key" = {};
    sops.templates.wg-private-key.content = config.sops.placeholder."wireguard/private-key";
    sops.templates.wg-private-key.owner = "systemd-network";
    # The rendered unit only references the key file, so restart the tunnel explicitly when the key changes.
    sops.secrets."wireguard/private-key".restartUnits = ["wireguard-${cfg.iface}.service"];

    sops.secrets."wireguard/fluffy-pubkey_unencrypted" = {};
    sops.templates.wg-peer-public-key.content = config.sops.placeholder."wireguard/fluffy-pubkey_unencrypted";
    sops.templates.wg-peer-public-key.owner = "systemd-network";
    # The rendered unit only references the key file, so restart the tunnel explicitly when the key changes.
    sops.secrets."wireguard/fluffy-pubkey_unencrypted".restartUnits = ["wireguard-${cfg.iface}.service"];

    # Secrets are currently installed by the activation script, which runs
    # before any service. If userborn/systemd-sysusers is ever enabled,
    # sops-nix switches to a boot-time unit without ordering guarantees, so
    # make the dependency explicit.
    systemd.services."wireguard-${cfg.iface}".after = ["sops-install-secrets.service"];

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
          # ensure file is readable by `systemd-network` user
          PrivateKeyFile = config.sops.templates.wg-private-key.path;
        };
        wireguardPeers = [
          {
            PublicKeyFile = config.sops.templates.wg-peer-public-key.path;
            AllowedIPs = ["${cfg.peerAddress}/32"];

            # Foggy is behind NAT, so it dials out to fluffy's public endpoint.
            # The keepalive holds the NAT mapping open, so fluffy can reach
            # foggy through the tunnel at any time.
            Endpoint = cfg.peerEndpoint;
            PersistentKeepalive = 25;
          }
        ];
      };
    };
  };
}
