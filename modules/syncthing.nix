{
  dataBaseDir,
  tld,
  ...
}: let
  serviceName = "syncthing";
  domain = "sync";
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "${dataBaseDir}/${serviceName}";

    overrideFolders = false;
    overrideDevices = false;

    # Do not submit anonymous usage data.
    settings.options.urAccepted = -1;
  };

  systemd.tmpfiles.rules = [
    "d ${dataBaseDir}/${serviceName} 0750 syncthing syncthing"
  ];

  systemd.services.syncthing.serviceConfig.UMask = "0027";

  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  services.caddy.virtualHosts."${domain}.${tld}".extraConfig = ''
    encode
    authorize with fluff-internal-auth
    # We additionally protect the Syncthing GUI with IP blocking.
    import fluff-home-ips-only
    # https://docs.syncthing.net/users/reverseproxy.html
    reverse_proxy http://127.0.0.1:8384 {
      header_up Host {upstream_hostport}
    }
  '';
}
