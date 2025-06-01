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
    import top_level_basic_auth
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
      echo-server = {
        autoStart = true;
        serviceConfig = {
          RestartSec = "10";
          Restart = "always";
        };
        containerConfig = {
          image = "docker.io/mendhak/http-https-echo:31";
          publishPorts = ["127.0.0.1:${toString internal-port}:8080"];
          userns = "keep-id";
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/persisted-data"];
        };
      };
    };
  };
}
