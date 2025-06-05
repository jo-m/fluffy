{
  internal-port,
  service-name,
}: {
  username,
  uid,
  tld,
  data-base-dir,
  config,
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

  sops.secrets."openobserve/user" = {};
  sops.secrets."openobserve/password" = {};
  sops.templates.openobserve-auth.content = ''
    # https://openobserve.ai/docs/environment-variables/
    ZO_ROOT_USER_EMAIL=${config.sops.placeholder."openobserve/user"}
    ZO_ROOT_USER_PASSWORD=${config.sops.placeholder."openobserve/password"}
  '';
  sops.templates.openobserve-auth.owner = username;

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
          image = "public.ecr.aws/zinclabs/openobserve:latest";
          autoUpdate = "registry";
          name = "${service-name}";

          userns = "";
          publishPorts = ["127.0.0.1:${toString internal-port}:5080"];
          mounts = ["type=bind,src=${data-base-dir}/${service-name},dst=/data"];

          environments = {
            # https://openobserve.ai/docs/environment-variables/
            RUST_BACKTRACE = "full";
            ZO_HTTP_PORT = "5080";
            ZO_HTTP_ADDR = "5080";
            ZO_HTTP_IPV6_ENABLED = "true";
            ZO_TELEMETRY = "false";
          };
          environmentFiles = [config.sops.templates.openobserve-auth.path];
        };
      };
    };
  };
}
