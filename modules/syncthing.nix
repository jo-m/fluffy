{
  pkgs,
  data-base-dir,
  tld,
  ...
}: let
  dataDir = "${data-base-dir}/sync";
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "${data-base-dir}/sync";
    # settings.gui = {
    #   user = "user";
    #   password = "W6SV8iV4pJpCasdasd9GKVpFiAmJmZCh4wwezkwHMCsdzcPLJt"; # TODO: deploy via sops.
    # };
    settings.options.urAccepted = -1;
  };

  # https://docs.syncthing.net/users/reverseproxy.html
  services.caddy.virtualHosts."sync.${tld}".extraConfig = ''
    import mybasicauth
    reverse_proxy http://127.0.0.1:8384 {
      header_up Host {upstream_hostport}
    }
  '';

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
}
