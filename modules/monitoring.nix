# Monitoring.
{
  config,
  pkgs,
  tld,
  ...
}: let
  domain = "monitoring";
  grafana-port = 20000;
  prom-port = 20001;
  prom-node-port = 20002;
in {
  services.caddy.virtualHosts."${domain}.${tld}" = {
    extraConfig = ''
      encode
      import fluff_global_rate_limit
      import fluff_global_basicauth
      reverse_proxy http://127.0.0.1:${toString grafana-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  services.grafana = {
    enable = true;
    domain = "${domain}.${tld}";
    port = grafana-port;
    openFirewall = false;
    addr = "127.0.0.1";

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
      ];
    };
  };

  # https://nixos.org/manual/nixos/stable/#module-services-prometheus-exporters
  services.prometheus.exporters.node = {
    enable = true;
    port = prom-node-port;
    openFirewall = false;
    # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/monitoring/prometheus/exporters.nix
    enabledCollectors = ["systemd"];
    # nix-shell -p prometheus-node-exporter --command 'node_exporter --help'
    extraFlags = ["--collector.ethtool" "--collector.softirqs" "--collector.tcpstat"];
  };

  # https://wiki.nixos.org/wiki/Prometheus
  # https://nixos.org/manual/nixos/stable/#module-services-prometheus-exporters-configuration
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/monitoring/prometheus/default.nix
  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "1m";
    listenAddress = "localhost";
    port = prom-port;
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = ["localhost:${toString config.services.prometheus.exporters.node.port}"];
          }
        ];
      }
    ];
  };
}
