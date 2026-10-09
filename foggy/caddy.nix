{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (config.custom) domain;
  cfg = config.services.foggy.caddy;
in {
  options.services.foggy.caddy = {
    bindIP = lib.mkOption {
      type = lib.types.str;
      description = "Default public IP to bind to";
      default = builtins.getEnv "FOGGY_REMOTE_IP4";
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = [80 443 8443];

    services.caddy = {
      enable = true;

      globalConfig = ''
        metrics{
          per_host
        }
      '';

      # Podfather portal.
      virtualHosts."${domain}" = {
        extraConfig = ''
          bind ${config.services.foggy.caddy.bindIP}
          tls internal
          encode
          reverse_proxy http://127.0.0.1:${toString config.services.podfather.port}
        '';
        logFormat = ''
          output stderr
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      # Caddy: warning: "certutil" is not available, install "certutil" with..
      nss
    ];
  };
}
