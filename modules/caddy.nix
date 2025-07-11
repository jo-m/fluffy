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
        "github.com/mholt/caddy-ratelimit@v0.1.1-0.20250318145942-a8e9f68d7bed"
        "github.com/mholt/caddy-webdav@v0.0.0-20250609161527-33ba3cd2088c"
      ];
      hash = "sha256-ZmrqejMy8uwzZxyrcfrENllehz4uRzXI7j0eYhogjTg=";
    };

    extraConfig = ''
      # Import config files with secrets.
      import ${config.sops.templates.caddy-global-basicauth.path}
      import ${config.sops.templates.caddy-home-ips.path}

      (fluff_global_rate_limit) {
        rate_limit {
          zone fluff_ratelimit_global_60s {
            key    static
            events 1000
            window 60s
          }
          zone fluff_ratelimit_global_10s {
            key    static
            events 200
            window 10s
          }
          zone fluff_ratelimit_global_1s {
            key    static
            events 100
            window 1s
          }

          zone fluff_ratelimit_per_remote_host_60s {
            key    {http.request.remote.host}
            events 500
            window 60s
          }
          zone fluff_ratelimit_per_remote_host_10s {
            key    {http.request.remote.host}
            events 100
            window 10s
          }
          zone fluff_ratelimit_per_remote_host_1s {
            key    {http.request.remote.host}
            events 50
            window 1s
          }
          log_key
        }
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
