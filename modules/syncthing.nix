{
  pkgs,
  data-base-dir,
  tld,
  config,
  ...
}: let
  service-name = "syncthing";
  domain = "sync";
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "${data-base-dir}/${service-name}";

    overrideFolders = false;
    overrideDevices = false;

    # Do not submit anonymous usage data.
    settings.options.urAccepted = -1;
  };

  systemd.tmpfiles.rules = [
    "d ${data-base-dir}/${service-name} 0750 syncthing syncthing"
  ];

  systemd.services.syncthing.serviceConfig.UMask = "0027";

  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  services.caddy.virtualHosts."${domain}.${tld}".extraConfig = ''
    encode
    authorize with fluff_internal_auth
    # We additionally protect the Syncthing GUI with IP blocking.
    import fluff_home_ips_only
    # https://docs.syncthing.net/users/reverseproxy.html
    reverse_proxy http://127.0.0.1:8384 {
      header_up Host {upstream_hostport}
    }
  '';
}
