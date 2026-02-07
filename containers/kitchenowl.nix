{
  config,
  lib,
  pkgs,
  username,
  tld,
  data-base-dir,
  ...
}: let
  cfg = config.services.fluffy.kitchenowl;
  outerConfig = config;
in {
  options.services.fluffy.kitchenowl = {
    enable = lib.mkEnableOption "Kitchenowl recipe and grocery manager" // {default = true;};

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
        # Has its own auth - thus, ratelimit.
        import fluff_global_rate_limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    sops.secrets."kitchenowl/jwt-secret-key" = {};
    sops.templates.kitchenowl-secret-env.content = ''
      # https://docs.kitchenowl.org/latest/self-hosting/advanced/
      JWT_SECRET_KEY=${outerConfig.sops.placeholder."kitchenowl/jwt-secret-key"}
    '';
    sops.templates.kitchenowl-secret-env.owner = username;

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
      "d ${data-base-dir}/${cfg.serviceName}/upload 0750 ${username} ${username}"
    ];

    home-manager.users."${username}" = {
      pkgs,
      config,
      ...
    }: let
      inherit (config.virtualisation.quadlet) networks;
    in {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.networks."${cfg.serviceName}".networkConfig.name = cfg.serviceName;
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}-frontend" = {
          autoStart = true;
          # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
          serviceConfig = {
            Restart = "always";
            RestartSec = "100ms";
            RestartSteps = "10";
            RestartMaxDelaySec = "60s";
          };
          unitConfig = {
            After = [
              "${cfg.serviceName}-backend.service"
            ];
            Requires = [
              "${cfg.serviceName}-backend.service"
            ];
          };
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "docker.io/tombursch/kitchenowl-web:latest";
            autoUpdate = "registry";
            name = "${cfg.serviceName}-frontend";

            userns = "";
            podmanArgs = ["--umask=0027"];
            environments = {
              # https://docs.kitchenowl.org/latest/self-hosting/advanced/
              BACK_URL = "${cfg.serviceName}-backend:5000";
            };
            publishPorts = ["127.0.0.1:${toString cfg.port}:80"];
            networks = [networks."${cfg.serviceName}".ref];
          };
        };
        "${cfg.serviceName}-backend" = {
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
            image = "docker.io/tombursch/kitchenowl-backend:latest";
            autoUpdate = "registry";
            name = "${cfg.serviceName}-backend";

            userns = "";
            podmanArgs = ["--umask=0027"];
            mounts = ["type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/data"];
            environments = {
              # https://docs.kitchenowl.org/latest/self-hosting/advanced/
              JWT_REFRESH_TOKEN_EXPIRES = "1440"; # Minutes -> 12h.
              DISABLE_ONBOARDING = "false";
              OPEN_REGISTRATION = "false";
              STORAGE_PATH = "/data";
            };
            environmentFiles = [outerConfig.sops.templates.kitchenowl-secret-env.path];
            networks = [networks."${cfg.serviceName}".ref];
          };
        };
      };
    };
  };
}
