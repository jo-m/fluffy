{
  internal-port,
  service-name,
  domain,
}: {
  username,
  uid,
  tld,
  data-base-dir,
  ...
}: {
  services.caddy.virtualHosts."${domain}.${tld}" = {
    extraConfig = ''
      encode
      import fluff_global_rate_limit

      # Readeck auth is incompatible with global basic auth.

      reverse_proxy http://127.0.0.1:${toString internal-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 ${toString uid} ${toString uid}"
  ];

  home-manager.users."${username}" = {
    pkgs,
    config,
    ...
  }: {
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
          image = "codeberg.org/readeck/readeck:latest";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "keep-id";
          publishPorts = ["127.0.0.1:${toString internal-port}:8000"];
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/readeck"];
          environments = {
            # https://readeck.org/en/docs/configuration
            READECK_LOG_LEVEL = "info";
            READECK_SERVER_HOST = "0.0.0.0";
            READECK_SERVER_PORT = "8000";
            READECK_TRUSTED_PROXIES = "127.0.0.1";
          };
        };
      };
    };
  };
}
