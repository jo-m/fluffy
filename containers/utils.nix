{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) username tld;
  cfg = config.services.fluffy.utils;
  containerLib = import ./lib.nix;
in {
  options.services.fluffy.utils = {
    enable = lib.mkEnableOption "Utils subdomain for small tools" // {default = true;};

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain for Caddy reverse proxy";
    };

    cyberchef = {
      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "cyberchef";
        description = "Systemd service name for the CyberChef container";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "Internal container port for CyberChef";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode
        import fluff-global-rate-limit

        redir /cc /cc/

        handle_path /cc/* {
          reverse_proxy http://127.0.0.1:${toString cfg.cyberchef.port}
        }

        handle {
          respond "Not found" 404
        }
      '';
      logFormat = "output stderr";
    };

    home-manager.users."${username}" = _: {
      virtualisation.quadlet.containers = {
        "${cfg.cyberchef.serviceName}" = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          containerConfig = {
            image = "ghcr.io/gchq/cyberchef:latest";
            autoUpdate = "registry";
            name = cfg.cyberchef.serviceName;

            userns = "";
            publishPorts = ["127.0.0.1:${toString cfg.cyberchef.port}:80"];
          };
        };
      };
    };
  };
}
