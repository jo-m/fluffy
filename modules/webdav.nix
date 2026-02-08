{
  username,
  tld,
  dataBaseDir,
  config,
  ...
}: let
  serviceName = "webdav";
  domain = "webdav";
in {
  sops.secrets."caddy/webdav-basicauth" = {};
  sops.templates.caddy-webdav-basicauth.content = ''
    basic_auth {
      ${config.sops.placeholder."caddy/webdav-basicauth"}
    }
  '';
  sops.templates.caddy-webdav-basicauth.owner = "caddy";

  services.caddy.virtualHosts."${domain}.${tld}" = {
    extraConfig = ''
      encode

      import ${config.sops.templates.caddy-webdav-basicauth.path}

      route {
          webdav {
              root ${dataBaseDir}/${serviceName}
              prefix /
          }
      }
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };

  systemd.tmpfiles.rules = [
    "d ${dataBaseDir}/${serviceName} 0750 caddy caddy"
  ];
}
