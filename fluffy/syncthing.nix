{config, ...}: let
  inherit (config.custom) data-base-dir domain;
  serviceName = "syncthing";
  subdomain = "sync";
in {
  services.podfather.external-apps.SYNCTHING = {
    name = "Syncthing GUI";
    icon = "🔄";
    category = "Apps";
    description = "Only from home IP";
    url = "https://${subdomain}.${domain}/";
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

  services.caddy.virtualHosts."${subdomain}.${domain}".extraConfig = ''
    encode
    authorize with fluff-auth-policy
    # We additionally protect the Syncthing GUI with IP blocking.
    import fluff-home-ips-only
    # https://docs.syncthing.net/users/reverseproxy.html
    reverse_proxy http://127.0.0.1:8384 {
      header_up Host {upstream_hostport}
    }
  '';
}
