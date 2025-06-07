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
      # No basic auth here.
      reverse_proxy http://127.0.0.1:${toString internal-port}
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  sops.secrets."hemmelig/username" = {};
  sops.secrets."hemmelig/email" = {};
  sops.secrets."hemmelig/password" = {};
  sops.secrets."hemmelig/jwt-secret" = {};

  sops.templates.hemmelig-secret-env.content = ''
    # https://github.com/HemmeligOrg/Hemmelig.app/blob/main/docker-compose.yml
    SECRET_ROOT_USER=${config.sops.placeholder."hemmelig/username"}
    SECRET_ROOT_EMAIL=${config.sops.placeholder."hemmelig/email"}
    SECRET_ROOT_PASSWORD=${config.sops.placeholder."hemmelig/password"}
    SECRET_JWT_SECRET=${config.sops.placeholder."hemmelig/jwt-secret"}
  '';
  sops.templates.hemmelig-secret-env.owner = username;

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 ${username} ${username}"
    "d ${data-base-dir}/${service-name}/files 0750 ${username} ${username}"
    "d ${data-base-dir}/${service-name}/db 0750 ${username} ${username}"
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
          image = "docker.io/hemmeligapp/hemmelig:v6";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "";
          podmanArgs = ["--umask=0027"];
          user = "root"; # The Hemmelig Dockerfile creates a "node" user which breaks the bind mount permissions.
          publishPorts = ["127.0.0.1:${toString internal-port}:3000"];
          mounts = [
            "type=bind,src=${data-base-dir}/${service-name}/files,dst=/var/tmp/hemmelig/upload/files"
            "type=bind,src=${data-base-dir}/${service-name}/db,dst=/home/node/hemmelig/database/"
          ];
          environments = {
            # https://github.com/HemmeligOrg/Hemmelig.app/blob/main/docker-compose.yml
            SECRET_LOCAL_HOSTNAME = "0.0.0.0";
            SECRET_PORT = "3000";
            SECRET_HOST = "${domain}.${tld}";
            SECRET_FILE_SIZE = "1";
            SECRET_FORCED_LANGUAGE = "en";
            SECRET_MAX_TEXT_SIZE = "512";
          };
          environmentFiles = [config.sops.templates.hemmelig-secret-env.path];
        };
      };
    };
  };
}
