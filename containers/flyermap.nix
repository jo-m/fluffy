{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) username tld data-base-dir;
  cfg = config.services.fluffy.flyermap;
  containerLib = import ./lib.nix;
in {
  options.services.fluffy.flyermap = {
    enable = lib.mkEnableOption "Flyermap flyer management service" // {default = true;};

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
        import fluff-global-rate-limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

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
            image = "ghcr.io/jo-m/flyermap:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "keep-id";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:8000"];
            mounts = ["type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/data"];
            environments = {
              PORT = "8000";
              # TODO: Move credentials to sops secrets
              FLYERMAP_USERS = ''
                {
                  "joni":"QR4DAWGB0wZSO4/vxVmtsA==:U/znDg5aMHh+Txe9Rp14LxI+NRUpGdYb/z9CD8MBjVM=",
                  "test":"107SUnnplT0GqnFHcVdBzA==:CrBPvwNA+0HWKIkB+skyfubx0Ebw/W4CqVI0iJCc6SA="
                }
              '';
            };
          };
        };
      };
    };
  };
}
