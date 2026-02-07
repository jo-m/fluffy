{
  config,
  lib,
  pkgs,
  username,
  tld,
  data-base-dir,
  ...
}: let
  cfg = config.services.fluffy.readeck;
in {
  options.services.fluffy.readeck = {
    enable = lib.mkEnableOption "Readeck bookmark manager" // {default = true;};

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

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode
        # Hast its own auth - thus, ratelimit.
        import fluff_global_rate_limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
    ];

    home-manager.users."${username}" = {
      pkgs,
      config,
      ...
    }: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
          serviceConfig = {
            Restart = "always";
            RestartSec = "100ms";
            RestartSteps = "10";
            RestartMaxDelaySec = "60s";
          };
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "codeberg.org/readeck/readeck:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "keep-id";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:8000"];
            mounts = ["type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/readeck"];
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
