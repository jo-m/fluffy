{config, ...}: let
  inherit (config.custom) data-base-dir domain;
  serviceName = "webdav";
  subdomain = "webdav";
in {
  sops.secrets."caddy/webdav-basicauth" = {};
  sops.templates.caddy-webdav-basicauth.content = ''
    basic_auth {
      ${config.sops.placeholder."caddy/webdav-basicauth"}
    }
  '';
  sops.templates.caddy-webdav-basicauth.owner = "caddy";

  services.caddy.virtualHosts."${subdomain}.${domain}" = {
    extraConfig = ''
      encode

      import ${config.sops.templates.caddy-webdav-basicauth.path}

      route {
          webdav {
              root ${data-base-dir}/${serviceName}
              prefix /
          }
      }
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${serviceName} 0750 caddy caddy"
  ];
}
