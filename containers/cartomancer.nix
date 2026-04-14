{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) username tld data-base-dir;
  cfg = config.services.fluffy.cartomancer;
  outerConfig = config;
  containerLib = import ./lib.nix;
in {
  options.services.fluffy.cartomancer = {
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
        # Public, no auth - thus, ratelimit.
        import fluff-global-rate-limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    sops.secrets."cartomancer/APP_INIT_ADMIN_EMAIL" = {};
    sops.secrets."cartomancer/SESSION_JWT_SECRET" = {};
    sops.secrets."cartomancer/APP_EMAIL_JWT_SECRET" = {};

    sops.templates.cartomancer-secret-env.content = ''
      APP_INIT_ADMIN_EMAIL=${outerConfig.sops.placeholder."cartomancer/APP_INIT_ADMIN_EMAIL"}
      SESSION_JWT_SECRET=${outerConfig.sops.placeholder."cartomancer/SESSION_JWT_SECRET"}
      APP_EMAIL_JWT_SECRET=${outerConfig.sops.placeholder."cartomancer/APP_EMAIL_JWT_SECRET"}
    '';
    sops.templates.cartomancer-secret-env.owner = username;

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
            # https://github.com/jo-m/cartomancer/pkgs/container/cartomancer
            image = "ghcr.io/jo-m/cartomancer:0.1.3";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            podmanArgs = ["--umask=0027" "--cpus=2"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:8080"];
            mounts = ["type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/data"];
            exec = "serve";
            environments = {
              LOG_PRETTY = "false";
              APP_REGISTRATION_ENABLED = "false";
              JOBS_MAX_PARALLEL = "1";
            };
            memory = "2g";
            environmentFiles = [outerConfig.sops.templates.cartomancer-secret-env.path];
            labels = containerLib.podfatherLabels {
              name = "Cartomancer";
              icon = "🪄";
              category = "Apps";
              url = "https://${cfg.domain}.${tld}/";
            };
          };
        };
      };
    };
  };
}
