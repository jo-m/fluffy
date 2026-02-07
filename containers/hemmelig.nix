{
  config,
  lib,
  pkgs,
  username,
  tld,
  data-base-dir,
  ...
}: let
  cfg = config.services.fluffy.hemmelig;
  outerConfig = config;
in {
  options.services.fluffy.hemmelig = {
    enable = lib.mkEnableOption "Hemmelig secrets sharing service" // {default = true;};

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
        # Public, no auth - thus, ratelimit.
        import fluff_global_rate_limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    sops.secrets."hemmelig/username" = {};
    sops.secrets."hemmelig/email" = {};
    sops.secrets."hemmelig/password" = {};
    sops.secrets."hemmelig/jwt-secret" = {};

    sops.templates.hemmelig-secret-env.content = ''
      # https://github.com/HemmeligOrg/Hemmelig.app/blob/main/docker-compose.yml
      SECRET_ROOT_USER=${outerConfig.sops.placeholder."hemmelig/username"}
      SECRET_ROOT_EMAIL=${outerConfig.sops.placeholder."hemmelig/email"}
      SECRET_ROOT_PASSWORD=${outerConfig.sops.placeholder."hemmelig/password"}
      SECRET_JWT_SECRET=${outerConfig.sops.placeholder."hemmelig/jwt-secret"}
    '';
    sops.templates.hemmelig-secret-env.owner = username;

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
      "d ${data-base-dir}/${cfg.serviceName}/files 0750 ${username} ${username}"
      "d ${data-base-dir}/${cfg.serviceName}/db 0750 ${username} ${username}"
    ];

    home-manager.users."${username}" = {pkgs, ...}: {
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
            image = "docker.io/hemmeligapp/hemmelig:v6";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            podmanArgs = ["--umask=0027"];
            user = "root"; # The Hemmelig Dockerfile creates a "node" user which breaks the bind mount permissions.
            publishPorts = ["127.0.0.1:${toString cfg.port}:3000"];
            mounts = [
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/files,dst=/var/tmp/hemmelig/upload/files"
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/db,dst=/home/node/hemmelig/database/"
            ];
            environments = {
              # https://github.com/HemmeligOrg/Hemmelig.app/blob/main/docker-compose.yml
              SECRET_LOCAL_HOSTNAME = "0.0.0.0";
              SECRET_PORT = "3000";
              SECRET_HOST = "${cfg.domain}.${tld}";
              SECRET_FILE_SIZE = "1";
              SECRET_FORCED_LANGUAGE = "en";
              SECRET_MAX_TEXT_SIZE = "512";
            };
            environmentFiles = [outerConfig.sops.templates.hemmelig-secret-env.path];
          };
        };
      };
    };
  };
}
