{
  config,
  lib,
  pkgs,
  username,
  tld,
  data-base-dir,
  ...
}:
with lib; let
  cfg = config.services.fluffy.qr;
in {
  options.services.fluffy.qr = {
    enable = mkEnableOption "QR code generator service" // {default = true;};

    serviceName = mkOption {
      type = types.str;
      description = "Systemd service name for the container";
    };

    domain = mkOption {
      type = types.str;
      description = "Domain for Caddy reverse proxy";
    };

    port = mkOption {
      type = types.port;
      description = "Internal container port";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode
        import fluff_global_rate_limit
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
          containerConfig = {
            image = "ghcr.io/lyqht/mini-qr:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            publishPorts = ["127.0.0.1:${toString cfg.port}:8080"];
          };
        };
      };
    };
  };
}
