{...}: let
  username = "runner";
  uid = 1000;
  internal-port = 9001;
  tld = "test123.example.org";
  service-name = "echo";
in {
  services.caddy.virtualHosts."${service-name}.${tld}".extraConfig = ''
    encode
    reverse_proxy http://127.0.0.1:${toString internal-port}
  '';

  systemd.tmpfiles.rules = [
    "d /data/${service-name} 0750 ${toString uid} ${toString uid}"
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
          mounts = ["type=bind,src=/data/${service-name},dst=/persisted-data"];
        };
      };
    };
  };
}
