{
  tld,
  config,
  pkgs,
  ...
}: {
  sops.secrets."caddy/global-basicauth" = {};
  sops.templates.caddy-global-basicauth.content = ''
    (fluff_global_basicauth) {
      basic_auth {
        ${config.sops.placeholder."caddy/global-basicauth"}
      }
    }
  '';
  sops.templates.caddy-global-basicauth.owner = "caddy";

  sops.secrets."caddy/home-ips" = {};
  sops.templates.caddy-home-ips.content = ''
    (fluff_home_ips_only) {
      @denied not remote_ip ${config.sops.placeholder."caddy/home-ips"}
      abort @denied
    }
  '';
  sops.templates.caddy-home-ips.owner = "caddy";

  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [
        # To update: Put entire git rev after @, build, correct version will be in the error message.
        # https://github.com/mholt/caddy-ratelimit
        "github.com/mholt/caddy-ratelimit@v0.1.1-0.20250915152450-04ea34edc0c4"
        # https://github.com/mholt/caddy-webdav
        "github.com/mholt/caddy-webdav@v0.0.0-20250805175825-7a5c90d8bf90"
      ];
      hash = "sha256-1O0mnv/J7XetfGeOH9ssuaaZ5LGXr0mclM6INNhEXRk=";
    };

    globalConfig = ''
      metrics{
        per_host
      }
    '';

    extraConfig = ''
      # Import config files with secrets.
      import ${config.sops.templates.caddy-global-basicauth.path}
      import ${config.sops.templates.caddy-home-ips.path}

      ${builtins.readFile ./fluff_global_rate_limit.Caddyfile}
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
