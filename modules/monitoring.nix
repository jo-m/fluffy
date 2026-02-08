# Monitoring.
{
  config,
  pkgs,
  tld,
  hostname,
  ...
}: let
  grafanaDomain = "monitor";
  grafanaPort = 20000;
  promPort = 20001;
  promNodePort = 20002;

  promtailPort = 20003;
  lokiPort = 20004;
in {
  services.caddy.virtualHosts."${grafanaDomain}.${tld}" = {
    extraConfig = ''
      encode
      authorize with fluff-internal-auth
      reverse_proxy http://127.0.0.1:${toString grafanaPort}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  services.grafana = {
    enable = true;
    settings.server = {
      domain = "${grafanaDomain}.${tld}";
      http_port = grafanaPort;
      http_addr = "127.0.0.1";
      root_url = "https://${grafanaDomain}.${tld}";
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

  services.loki = {
    enable = true;
    # https://grafana.com/docs/loki/latest/configure/examples/configuration-examples/
    configFile = pkgs.writeText "loki.yaml" ''
      auth_enabled: false

      server:
        http_listen_port: ${toString lokiPort}

      common:
        ring:
          instance_addr: 127.0.0.1
          kvstore:
            store: inmemory
        replication_factor: 1
        path_prefix: /tmp/loki

      schema_config:
        configs:
        - from: 2020-05-15
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: index_
            period: 24h

      storage_config:
        filesystem:
          directory: /tmp/loki/chunks
    '';
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = promtailPort;
        grpc_listen_port = 0;
      };
      positions = {
        filename = "/tmp/positions.yaml";
      };
      clients = [
        {
          url = "http://127.0.0.1:${toString lokiPort}/loki/api/v1/push";
        }
      ];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = hostname;
            };
          };
          relabel_configs = [
            {
              source_labels = ["__journal__systemd_unit"];
              target_label = "unit";
            }
            {
              source_labels = ["__journal__systemd_user_unit"];
              target_label = "user_unit";
            }
          ];
        }
      ];
    };
  };

  # https://nixos.org/manual/nixos/stable/#module-services-prometheus-exporters
  services.prometheus.exporters.node = {
    enable = true;
    port = promNodePort;
    openFirewall = false;
    # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/monitoring/prometheus/exporters.nix
    enabledCollectors = ["systemd"];
    # nix-shell -p prometheus-node-exporter --command 'node_exporter --help'
    extraFlags = ["--collector.softirqs" "--collector.tcpstat"];
  };

  # https://wiki.nixos.org/wiki/Prometheus
  # https://nixos.org/manual/nixos/stable/#module-services-prometheus-exporters-configuration
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/monitoring/prometheus/default.nix
  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "15s";
    listenAddress = "localhost";
    port = promPort;
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = ["localhost:${toString config.services.prometheus.exporters.node.port}"];
          }
        ];
      }
      # https://caddyserver.com/docs/metrics
      {
        job_name = "caddy";
        static_configs = [
          {
            targets = ["localhost:2019"];
          }
        ];
      }
    ];
  };
}
