{
  config,
  lib,
  ...
}: let
  inherit (config.custom) domain;
in {
  options.services.foggy.caddy = {
    bindIP = lib.mkOption {
      type = lib.types.str;
      description = "Default public IP to bind to";
      default = builtins.getEnv "FOGGY_REMOTE_IP4";
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = [80 443];

    sops.secrets."caddy/pki-root-key" = {
      owner = "caddy";
      group = "caddy";
      mode = "0400";
      # Caddy only reads the CA key at startup.
      restartUnits = ["caddy.service"];
    };

    services.caddy = {
      enable = true;

      globalConfig = ''
        metrics{
          per_host
        }

        # Trust is distributed manually (foggy/ca.crt), so do not try to
        # install the root into this host's trust store.
        skip_install_trust

        # Stable local CA so clients can trust foggy/ca.crt instead of
        # whatever root Caddy generates in its data directory.
        pki {
          ca foggy {
            name "Foggy Local CA"
            root {
              cert ${./ca.crt}
              key ${config.sops.secrets."caddy/pki-root-key".path}
            }
          }
        }
      '';

      # Podfather portal.
      virtualHosts."${domain}" = {
        extraConfig = ''
          bind ${config.services.foggy.caddy.bindIP}
          tls {
            issuer internal {
              ca foggy
            }
          }
          encode
          reverse_proxy http://127.0.0.1:${toString config.services.podfather.port}
        '';
        logFormat = ''
          output stderr
        '';
      };
    };
  };
}
