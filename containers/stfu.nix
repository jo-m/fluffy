{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) tld;
  cfg = config.services.fluffy.stfu;
in {
  options.services.fluffy.stfu = {
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain for Caddy reverse proxy";
    };
  };

  config = {
    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode
        # Public, no auth - thus, ratelimit.
        import fluff-global-rate-limit
        root * ${builtins.dirOf ./stfu.html}
        rewrite * /stfu.html
        file_server
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };
  };
}
