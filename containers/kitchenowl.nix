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
}: let
  outerConfig = config;
in {
  services.caddy.virtualHosts."${domain}.${tld}" = {
    extraConfig = ''
      encode
      import fluff_global_rate_limit
      reverse_proxy http://127.0.0.1:${toString internal-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  sops.secrets."kitchenowl/jwt-secret-key" = {};
  sops.templates.kitchenowl-secret-env.content = ''
    # https://docs.kitchenowl.org/latest/self-hosting/advanced/
    JWT_SECRET_KEY=${config.sops.placeholder."kitchenowl/jwt-secret-key"}
  '';
  sops.templates.kitchenowl-secret-env.owner = username;

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 ${username} ${username}"
  ];

  home-manager.users."${username}" = {
    pkgs,
    config,
    ...
  }: let
    inherit (config.virtualisation.quadlet) networks;
  in {
    # https://seiarotg.github.io/quadlet-nix/nixos-options.html
    virtualisation.quadlet.networks."${service-name}".networkConfig.name = service-name;
    virtualisation.quadlet.containers = {
      "${service-name}-frontend" = {
        autoStart = true;
        # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
        serviceConfig = {
          Restart = "always";
          RestartSec = "100ms";
          RestartSteps = "10";
          RestartMaxDelaySec = "60s";
        };
        unitConfig = {
          After = [
            "${service-name}-backend.service"
          ];
          Requires = [
            "${service-name}-backend.service"
          ];
        };
        # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
        containerConfig = {
          image = "docker.io/tombursch/kitchenowl-web:latest";
          autoUpdate = "registry";
          name = "${service-name}-frontend";

          userns = "";
          podmanArgs = ["--umask=0027"];
          environments = {
            # https://docs.kitchenowl.org/latest/self-hosting/advanced/
            BACK_URL = "${service-name}-backend:5000";
          };
          publishPorts = ["127.0.0.1:${toString internal-port}:80"];
          networks = [networks."${service-name}".ref];
        };
      };
      "${service-name}-backend" = {
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
          image = "docker.io/tombursch/kitchenowl-backend:latest";
          autoUpdate = "registry";
          name = "${service-name}-backend";

          userns = "";
          podmanArgs = ["--umask=0027"];
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/data"];
          environments = {
            # https://docs.kitchenowl.org/latest/self-hosting/advanced/
            JWT_REFRESH_TOKEN_EXPIRES = "1440"; # Minutes -> 12h.
            DISABLE_ONBOARDING = "false";
            OPEN_REGISTRATION = "false";
            STORAGE_PATH = "/data";
          };
          environmentFiles = [outerConfig.sops.templates.kitchenowl-secret-env.path];
          networks = [networks."${service-name}".ref];
        };
      };
    };
  };
}
