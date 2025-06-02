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
    import fluff_global_basicauth
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
          image = "ghcr.io/lyqht/mini-qr:latest";
          publishPorts = ["127.0.0.1:${toString internal-port}:8080"];
        };
      };
    };
  };
}
