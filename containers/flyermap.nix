{
  internal-port,
  service-name,
  domain,
}: {
  username,
  tld,
  data-base-dir,
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
          image = "ghcr.io/jo-m/flyermap:latest";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "keep-id";
          podmanArgs = ["--umask=0027"];
          publishPorts = ["127.0.0.1:${toString internal-port}:8000"];
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/data"];
          environments = {
            PORT = "8000";
            FLYERMAP_USERS = ''
              {
                "joni":"QR4DAWGB0wZSO4/vxVmtsA==:U/znDg5aMHh+Txe9Rp14LxI+NRUpGdYb/z9CD8MBjVM=",
                "test":"107SUnnplT0GqnFHcVdBzA==:CrBPvwNA+0HWKIkB+skyfubx0Ebw/W4CqVI0iJCc6SA="
              }
            '';
          };
        };
      };
    };
  };
}
