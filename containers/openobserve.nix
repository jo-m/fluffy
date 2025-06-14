{
  internal-port,
  internal-port-grpc,
  service-name,
  domain,
}: {
  username,
  tld,
  data-base-dir,
  config,
  ...
}: {
  services.caddy.virtualHosts."${domain}.${tld}" = {
    extraConfig = ''
      encode
      import fluff_global_rate_limit
      reverse_proxy http://127.0.0.1:${toString internal-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 ${username} ${username}"
  ];

  sops.secrets."openobserve/user" = {};
  sops.secrets."openobserve/password" = {};
  sops.templates.openobserve-auth.content = ''
    # https://openobserve.ai/docs/environment-variables/
    ZO_ROOT_USER_EMAIL=${config.sops.placeholder."openobserve/user"}
    ZO_ROOT_USER_PASSWORD=${config.sops.placeholder."openobserve/password"}
  '';
  sops.templates.openobserve-auth.owner = username;

  home-manager.users."${username}" = {pkgs, ...}: {
    # https://seiarotg.github.io/quadlet-nix/nixos-options.html
    virtualisation.quadlet.containers = {
      "${service-name}" = {
        autoStart = true;
        # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
        serviceConfig = {
          Restart = "always";
          RestartSec = "100ms";
          RestartSteps = "10";
          RestartMaxDelaySec = "60s";
        };
        # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
        containerConfig = {
          image = "public.ecr.aws/zinclabs/openobserve:latest";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "";
          publishPorts = [
            "127.0.0.1:${toString internal-port}:5080"
            "127.0.0.1:${toString internal-port-grpc}:5081"
          ];
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/data/openobserve"];

          environments = {
            # https://openobserve.ai/docs/environment-variables/
            RUST_BACKTRACE = "full";
            ZO_HTTP_PORT = "5080";
            ZO_HTTP_ADDR = "127.0.0.1";
            ZO_HTTP_IPV6_ENABLED = "true";
            ZO_GRPC_PORT = "5081";
            ZO_GRPC_ADDR = "127.0.0.1";
            ZO_TELEMETRY = "false";
            ZO_DATA_DIR = "/data/openobserve";
            ZO_DATA_DB_DIR = "/data/openobserve/db";
            ZO_DATA_WAL_DIR = "/data/openobserve/wal";
            ZO_DATA_STREAM_DIR = "/data/openobserve/stream";
            ZO_DATA_IDX_DIR = "/data/openobserve/idx";
            ZO_INGEST_ALLOWED_UPTO = "24";
          };
          environmentFiles = [config.sops.templates.openobserve-auth.path];
        };
      };
    };
  };
}
