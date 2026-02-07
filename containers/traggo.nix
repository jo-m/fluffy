{
  config,
  lib,
  pkgs,
  username,
  tld,
  data-base-dir,
  ...
}: let
  cfg = config.services.fluffy.traggo;
  outerConfig = config;
in {
  options.services.fluffy.traggo = {
    enable = lib.mkEnableOption "Traggo time tracking application" // {default = true;};

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
        authorize with fluff_internal_auth
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    sops.secrets."traggo/username" = {};
    sops.secrets."traggo/password" = {};
    sops.templates.traggo-secret-env.content = ''
      # https://traggo.net/install/
      TRAGGO_DEFAULT_USER_NAME=${outerConfig.sops.placeholder."traggo/username"}
      TRAGGO_DEFAULT_USER_PASS=${outerConfig.sops.placeholder."traggo/password"}
    '';
    sops.templates.traggo-secret-env.owner = username;

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
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
            image = "ghcr.io/jo-m/traggo-server:amd64-latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:3030"];
            mounts = ["type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/opt/traggo/data"];
            environmentFiles = [outerConfig.sops.templates.traggo-secret-env.path];
          };
        };
      };
    };
  };
}
