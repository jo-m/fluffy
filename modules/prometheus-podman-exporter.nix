# Prometheus exporter for the rootless Podman instance.
#
# Runs as a home-manager systemd user service for the runner user so that it
# has access to the user's Podman API socket (the system-level Podman socket
# would only see root containers, of which there are none).
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.fluffy) username;
  cfg = config.fluffy.prometheus-podman-exporter;
in {
  options.fluffy.prometheus-podman-exporter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Enable the Prometheus Podman exporter user service.";
      default = true;
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Loopback port the exporter listens on.";
      default = 20005;
    };

    podman-socket = lib.mkOption {
      type = lib.types.str;
      description = ''
        Podman API socket URI (CONTAINER_HOST). Defaults to the rootless
        socket of the user the service runs as.
      '';
      default = "unix://%t/podman/podman.sock";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users."${username}" = _: {
      systemd.user.services.prometheus-podman-exporter = {
        Unit = {
          Description = "Prometheus exporter for Podman";
          Requires = ["podman.socket"];
          After = ["podman.socket"];
        };
        Service = {
          ExecStart = lib.concatStringsSep " " [
            "${pkgs.prometheus-podman-exporter}/bin/prometheus-podman-exporter"
            "--web.listen-address=127.0.0.1:${toString cfg.port}"
            "--collector.enable-all"
          ];
          Environment = [
            "CONTAINER_HOST=${cfg.podman-socket}"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };
    };
  };
}
