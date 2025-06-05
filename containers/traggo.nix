{
  internal-port,
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
      import fluff_global_basicauth
      reverse_proxy http://127.0.0.1:${toString internal-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  sops.secrets."traggo/username" = {};
  sops.secrets."traggo/password" = {};
  sops.templates.traggo-secret-env.content = ''
    # https://traggo.net/install/
    TRAGGO_DEFAULT_USER_NAME=${config.sops.placeholder."traggo/username"}
    TRAGGO_DEFAULT_USER_PASS=${config.sops.placeholder."traggo/password"}
  '';
  sops.templates.traggo-secret-env.owner = username;

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 ${username} ${username}"
  ];

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
          image = "docker.io/traggo/server:latest";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "";
          publishPorts = ["127.0.0.1:${toString internal-port}:3030"];
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/opt/traggo/data"];
          environmentFiles = [config.sops.templates.traggo-secret-env.path];
        };
      };
    };
  };
}
