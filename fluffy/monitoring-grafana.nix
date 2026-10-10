# Monitoring.
{config, ...}: let
  inherit (config.custom) domain;

  grafanaSubdomain = "monitor";
  grafanaPort = 20000;

  lokiPort = 20004;
in {
  services.podfather.external-apps.GRAFANA = {
    name = "Grafana";
    icon = "📈";
    category = "Infrastructure";
    description = "Metrics & Logs";
    url = "https://${grafanaSubdomain}.${domain}/";
  };

  services.caddy.virtualHosts."${grafanaSubdomain}.${domain}" = {
    extraConfig = ''
      encode
      authorize with fluff-auth-policy
      reverse_proxy http://127.0.0.1:${toString grafanaPort}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        domain = "${grafanaSubdomain}.${domain}";
        http_port = grafanaPort;
        http_addr = "127.0.0.1";
        root_url = "https://${grafanaSubdomain}.${domain}";
      };
      # Since NixOS 26.05 there is no longer a default
      # and hardcoding it is fine for our case (no secrets in the db).
      security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
    };
    openFirewall = false;

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
          editable = false;
        }

        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString lokiPort}";
        }
      ];
    };
  };
}
