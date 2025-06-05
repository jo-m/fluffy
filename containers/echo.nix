{
  internal-port,
  service-name,
}: {
  username,
  uid,
  tld,
  data-base-dir,
  ...
}: {
  services.caddy.virtualHosts."${service-name}.${tld}" = {
    extraConfig = ''
      encode
      import fluff_global_rate_limit
      import fluff_global_basicauth
      reverse_proxy http://127.0.0.1:${toString internal-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

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
          image = "docker.io/mendhak/http-https-echo:latest";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "keep-id";
          publishPorts = ["127.0.0.1:${toString internal-port}:8080"];
        };
      };
    };
  };
}
