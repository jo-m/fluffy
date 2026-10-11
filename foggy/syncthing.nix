{config, ...}: let
  inherit (config.custom) data-base-dir domain;
  serviceName = "syncthing";
  externalPort = 10443;
in {
  services.podfather.external-apps.SYNCTHING = {
    name = "Syncthing GUI";
    icon = "🔄";
    category = "Apps";
    url = "https://${domain}:${toString externalPort}/";
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "${data-base-dir}/${serviceName}";

    overrideFolders = false;
    overrideDevices = false;

    # Do not submit anonymous usage data.
    settings.options.urAccepted = -1;
  };

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${serviceName} 0750 syncthing syncthing"
  ];

  systemd.services.syncthing.serviceConfig.UMask = "0027";

  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  networking.firewall.allowedTCPPorts = [externalPort];
  services.caddy.virtualHosts."${domain}:${toString externalPort}" = {
    extraConfig = ''
      bind ${config.services.foggy.caddy.bindIP}
      tls internal
      encode
      # https://docs.syncthing.net/users/reverseproxy.html
      reverse_proxy http://127.0.0.1:8384 {
        header_up Host {upstream_hostport}
      }
    '';
    # NixOS defaults to /var/log/caddy/access-*.log.
    logFormat = "output stderr";
  };
}
