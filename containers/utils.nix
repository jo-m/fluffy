{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) username tld;
  cfg = config.services.fluffy.utils;
  containerLib = import ./lib.nix;
  stfuHtml = ./stfu.html;
in {
  options.services.fluffy.utils = {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain for Caddy reverse proxy";
    };

    cyberchef.port = lib.mkOption {
      type = lib.types.port;
      description = "Internal container port for CyberChef";
    };
  };

  config = {
    fluffy.podfather.external-apps.STFU = {
      name = "STFU";
      icon = "🔇";
      category = "Utilities";
      url = "https://${cfg.domain}.${tld}/stfu/";
    };

    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode
        import fluff-global-rate-limit

        redir /cc /cc/
        handle_path /cc/* {
          reverse_proxy http://127.0.0.1:${toString cfg.cyberchef.port}
        }

        redir /stfu /stfu/
        handle_path /stfu/* {
          root * ${builtins.dirOf stfuHtml}
          rewrite * /stfu.html
          file_server
        }

        handle {
          respond "Not found" 404
        }
      '';
      logFormat = "output stderr";
    };

    home-manager.users."${username}" = _: {
      virtualisation.quadlet.containers = {
        cyberchef = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          containerConfig = {
            image = "ghcr.io/gchq/cyberchef:latest";
            autoUpdate = "registry";
            name = "cyberchef";

            userns = "";
            publishPorts = ["127.0.0.1:${toString cfg.cyberchef.port}:80"];
            labels = containerLib.podfatherLabels {
              name = "CyberChef";
              icon = "👨‍🍳";
              category = "Utilities";
              description = "Swiss Army Knife";
              url = "https://${cfg.domain}.${tld}/cc/";
            };
          };
        };
      };
    };
  };
}
