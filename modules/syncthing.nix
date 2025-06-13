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

  # Uncomment below to make Syncthing GUI accessible remotely.
  # services.caddy.virtualHosts."${domain}.${tld}".extraConfig = ''
  #   encode
  #   # We additionally protect the Syncthing GUI with IP blocking.
  #   import fluff_home_ips_only
  #   # Custom ratelimit as the Syncthing web GUI does a lot of requests...
  #   zone syncthing_ratelimit_global_1s {
  #     key    static
  #     events 200
  #     window 1s
  #   }
  #   import fluff_global_basicauth

  #   # https://docs.syncthing.net/users/reverseproxy.html
  #   reverse_proxy http://127.0.0.1:8384 {
  #     header_up Host {upstream_hostport}
  #   }
  # '';
}
