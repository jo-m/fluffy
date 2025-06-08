{
  tld,
  config,
  pkgs,
  lib,
  ...
}: let
  serviceName = "opentelemetry-collector";
  username = "opentelemetry-collector";
  openobserve-url = "http://127.0.0.1:30004/api/default";
  # https://github.com/openobserve/agents/blob/bf46fe5a4d440e3621ba826d4034bdf0ca243ef7/linux/install.sh#L49
  configFile = pkgs.writeText "opentelemetry-collector.yaml" ''
    receivers:
      journald:
        directory: /var/log/journal
      hostmetrics:
        root_path: /
        collection_interval: 30s
        scrapers:
          cpu:
          disk:
          filesystem:
          load:
          memory:
          network:
          paging:
          processes:
          # process: # a bug in the process scraper causes the collector to throw errors so disabling it for now
    processors:
      resourcedetection/system:
        detectors: ["system"]
        system:
          hostname_sources: ["os"]
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 15
      batch:
        send_batch_size: 10000
        timeout: 10s

    extensions:
      zpages: {}

    exporters:
      otlphttp/openobserve:
        endpoint: ${openobserve-url}
        headers:
          Authorization: "Basic ''${env:BASIC_AUTH}"
      otlphttp/openobserve_journald:
        endpoint: ${openobserve-url}
        headers:
          Authorization: "Basic ''${env:BASIC_AUTH}"
          stream-name: journald

    service:
      extensions: [zpages]
      pipelines:
        metrics:
          receivers: [hostmetrics]
          processors: [resourcedetection/system, memory_limiter, batch]
          exporters: [otlphttp/openobserve]
        logs/journald:
          receivers: [journald]
          processors: [resourcedetection/system, memory_limiter, batch]
          exporters: [otlphttp/openobserve_journald]
  '';
in {
  users.groups."${username}" = {};

  users.users."${username}" = {
    initialHashedPassword = "!";
    isNormalUser = true;
    group = username;
    extraGroups = ["users"];
  };

  sops.secrets."openobserve/basicauth" = {};
  sops.templates.openobserve-basicauth.content = ''
    BASIC_AUTH=${config.sops.placeholder."openobserve/basicauth"}
  '';
  sops.templates.openobserve-basicauth.owner = username;

  # https://github.com/openobserve/agents/blob/bf46fe5a4d440e3621ba826d4034bdf0ca243ef7/linux/install.sh#L115
  systemd.services."${serviceName}" = {
    enable = true;
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network.target" "network-online.target" "systemd-journald.service"];
    serviceConfig = {
      ExecStart = "${pkgs.opentelemetry-collector-contrib}/bin/otelcol-contrib --config ${configFile}";
      User = username;
      Group = "users";
      Restart = "always";
      RestartSec = "100ms";
      RestartSteps = "10";
      RestartMaxDelaySec = "60s";
      EnvironmentFile = config.sops.templates.openobserve-basicauth.path;
    };
  };
}
