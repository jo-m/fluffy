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
    settings.options.urAccepted = -1;
  };

  # Comment out to make Syncthing GUI accessible remotely.
  services.caddy.virtualHosts."${domain}.${tld}".extraConfig = ''
    encode
    # We additionally protect the Syncthing GUI with IP blocking.
    import fluff_home_ips_only
    import fluff_global_rate_limit
    import fluff_global_basicauth

    # https://docs.syncthing.net/users/reverseproxy.html
    reverse_proxy http://127.0.0.1:8384 {
      header_up Host {upstream_hostport}
    }
  '';

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
}
