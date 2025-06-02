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
      plugins = ["github.com/mholt/caddy-ratelimit@v0.1.0"];
      hash = "sha256-gn+FDt9GJ6bM1AJMUuBpLZqf/PXr5qYPHqB1kVy8ovQ=";
    };

    virtualHosts."${tld}".extraConfig = ''
      import fluff_global_rate_limit
      respond "Nothing to see here."
    '';

    extraConfig = ''
      # Import config files with secrets.
      import ${config.sops.templates.caddy-global-basicauth.path}
      import ${config.sops.templates.caddy-home-ips.path}

      (fluff_global_rate_limit) {
        rate_limit {
          zone fluff_ratelimit_global {
            key    static
            events 600
            window 1m
          }
          zone fluff_ratelimit_per_remote_host {
            key    {http.request.remote.host}
            events 200
            window 10s
          }
          log_key
        }
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
