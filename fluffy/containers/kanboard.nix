{
  config,
  lib,
  ...
}: let
  inherit (config.custom) username domain data-base-dir;
  cfg = config.services.fluffy.kanboard;
  containerLib = import ../../common/containers-lib.nix;
in {
  options.services.fluffy.kanboard = {
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
        authorize with fluff-auth-policy
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
      "d ${data-base-dir}/${cfg.serviceName}/data 0750 ${username} ${username}"
      "d ${data-base-dir}/${cfg.serviceName}/plugins 0750 ${username} ${username}"
    ];

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "docker.io/kanboard/kanboard:v1.2.54";
            autoUpdate = "registry";
            name = cfg.serviceName;

            # The entrypoint runs as root and chowns the data volumes to nginx (uid 100, gid 101 in the image).
            # `keep-id` maps that user to the host user, so files stay owned by `${username}`
            # and remain readable by the backup user.
            # `user = "root"` overrides keep-id's default of running the init process as the mapped user,
            # which the entrypoint and s6 need.
            userns = "keep-id:uid=100,gid=101";
            user = "root";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:80"];
            mounts = [
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/data,dst=/var/www/app/data"
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/plugins,dst=/var/www/app/plugins"
            ];
            environments = {
              # https://docs.kanboard.org/v1/admin/config
              PLUGIN_INSTALLER = "false";
              HIDE_LOGIN_FORM = "false";
            };
            labels = containerLib.podfatherLabels {
              name = "Kanboard";
              icon = "📋";
              category = "Apps";
              description = "Kanban";
              url = "https://${cfg.subdomain}.${domain}/board/1";
            };
          };
        };
      };
    };
  };
}
