{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) username tld data-base-dir;
  cfg = config.services.fluffy.readeck;
  containerLib = import ./lib.nix;
in {
  options.services.fluffy.readeck = {
    serviceName = lib.mkOption {
      type = lib.types.str;
      description = "Systemd service name for the container";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain for Caddy reverse proxy";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Internal container port";
    };
  };

  config = {
    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode

        # API is public (for app access), rate limited.
        handle /api/* {
          import fluff-global-rate-limit
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
        # Everything else behind auth portal.
        handle {
          authorize with fluff-auth-policy
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        }
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
    ];

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "codeberg.org/readeck/readeck:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "keep-id";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:8000"];
            mounts = ["type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/readeck"];
            labels = containerLib.podfatherLabels {
              name = "Readeck";
              icon = "📑";
              category = "Apps";
              description = "Bookmarks";
              url = "https://${cfg.domain}.${tld}/";
            };
            environments = {
              # https://readeck.org/en/docs/configuration
              READECK_LOG_LEVEL = "info";
              READECK_SERVER_HOST = "0.0.0.0";
              READECK_SERVER_PORT = "8000";
              READECK_TRUSTED_PROXIES = "127.0.0.1";
            };
          };
        };
      };
    };
  };
}
