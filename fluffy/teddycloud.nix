{
  config,
  lib,
  ...
}: let
  inherit (config.custom) domain;
  cfg = config.services.fluffy.teddycloud;
in {
  options.services.fluffy.teddycloud = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain for Caddy reverse proxy";
      default = "teddycloud";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Web UI port of teddycloud on foggy (must match services.foggy.teddycloud.port)";
      default = 30010;
    };
  };

  config = {
    services.podfather.external-apps.TEDDYCLOUD = {
      name = "Teddycloud";
      icon = "🧸";
      category = "Apps";
      description = "Foggy's teddycloud (tunnel)";
      url = "https://${cfg.subdomain}.${domain}/";
    };

    services.caddy.virtualHosts."${cfg.subdomain}.${domain}" = {
      extraConfig = ''
        encode
        authorize with fluff-auth-policy
        reverse_proxy http://${config.services.wireguard.peer-address}:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };
  };
}
