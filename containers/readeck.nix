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
  services.caddy.virtualHosts."${service-name}.${tld}".extraConfig = ''
    encode
    import fluff_global_rate_limit

    # Readeck auth is incompatible with global basic auth.

    reverse_proxy http://127.0.0.1:${toString internal-port}
  '';

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 ${toString uid} ${toString uid}"
  ];

  home-manager.users."${username}" = {
    pkgs,
    config,
    ...
  }: {
    virtualisation.quadlet.containers = {
      "${service-name}-server" = {
        autoStart = true;
        serviceConfig = {
          RestartSec = "10";
          Restart = "always";
        };
        containerConfig = {
          image = "codeberg.org/readeck/readeck:latest";
          publishPorts = ["127.0.0.1:${toString internal-port}:8000"];
          userns = "keep-id";
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/readeck"];
          environments = {
            # https://readeck.org/en/docs/configuration
            READECK_LOG_LEVEL = "info";
            READECK_SERVER_HOST = "0.0.0.0";
            READECK_SERVER_PORT = "8000";
            READECK_TRUSTED_PROXIES="127.0.0.1";
          };
        };
      };
    };
  };
}
