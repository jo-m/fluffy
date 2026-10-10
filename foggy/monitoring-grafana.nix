# Monitoring.
{config, ...}: let
  inherit (config.custom) domain;

  grafanaExternalPort = 9443;
  grafanaPort = 20000;

  lokiPort = 20004;
in {
  services.podfather.external-apps.GRAFANA = {
    name = "Grafana";
    icon = "📈";
    category = "Infrastructure";
    description = "Metrics & Logs";
    url = "https://${domain}:${toString grafanaExternalPort}/";
  };

  networking.firewall.allowedTCPPorts = [grafanaExternalPort];
  services.caddy.virtualHosts."${domain}:${toString grafanaExternalPort}" = {
    extraConfig = ''
      bind ${config.services.foggy.caddy.bindIP}
      tls internal
      encode
      reverse_proxy http://127.0.0.1:${toString grafanaPort}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        domain = "${domain}";
        http_port = grafanaPort;
        http_addr = "127.0.0.1";
        root_url = "https://${domain}:${toString grafanaExternalPort}";
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
