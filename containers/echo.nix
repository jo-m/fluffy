{
  config,
  lib,
  pkgs,
  username,
  tld,
  dataBaseDir,
  ...
}: let
  cfg = config.services.fluffy.echo;
in {
  options.services.fluffy.echo = {
    enable = lib.mkEnableOption "echo HTTP/HTTPS debugging service" // {default = true;};

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
        authorize with fluff-internal-auth
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

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
            image = "docker.io/mendhak/http-https-echo:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "keep-id";
            publishPorts = ["127.0.0.1:${toString cfg.port}:8080"];
          };
        };
      };
    };
  };
}
