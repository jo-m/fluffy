{
  config,
  lib,
  ...
}: let
  inherit (config.custom) username domain;
  cfg = config.services.fluffy.qr;
  containerLib = import ../../common/containers-lib.nix;
in {
  options.services.fluffy.qr = {
    serviceName = lib.mkOption {
      type = lib.types.str;
      description = "Systemd service name for the container";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain for Caddy reverse proxy";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Internal container port";
    };
  };

  config = {
    services.caddy.virtualHosts."${cfg.subdomain}.${domain}" = {
      extraConfig = ''
        encode
        # Public, no auth - thus, ratelimit.
        import fluff-global-rate-limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          containerConfig = {
            image = "ghcr.io/lyqht/mini-qr:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            publishPorts = ["127.0.0.1:${toString cfg.port}:8080"];
            labels = containerLib.podfatherLabels {
              name = "QR";
              icon = "📱";
              category = "Utilities";
              description = "Generate QR Codes";
              url = "https://${cfg.subdomain}.${domain}/";
            };
          };
        };
      };
    };
  };
}
