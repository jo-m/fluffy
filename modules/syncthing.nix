{
  pkgs,
  data-base-dir,
  tld,
  config,
  ...
}: let
  dataDir = "${data-base-dir}/sync";
in {
  sops.secrets."syncthing/devices/nixbox" = {};
  sops.secrets."syncthing/devices/pixel" = {};
  sops.secrets."syncthing/gui/jom" = {};

  sops.templates = {
    "syncthing-devices-nixbox".content = ''${config.sops.placeholder."syncthing/devices/nixbox"}'';
    "syncthing-devices-pixel".content = ''${config.sops.placeholder."syncthing/devices/pixel"}'';
    "syncthing-gui-jom".content = ''${config.sops.placeholder."syncthing/gui/jom"}'';
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "${data-base-dir}/sync";
    settings.gui = {
      user = "jom";
      password = config.sops.templates."syncthing-gui-jom".content;
    };
    settings.options.urAccepted = -1;
    settings.devices = {
      nixbox = {id = config.sops.templates."syncthing-devices-nixbox".content;};
      pixel = {id = config.sops.templates."syncthing-devices-pixel".content;};
    };
  };

  # https://docs.syncthing.net/users/reverseproxy.html
  services.caddy.virtualHosts."sync.${tld}".extraConfig = ''
    encode
    import fluff_global_rate_limit

    # No global basic auth, as this would conflict with Syncthing's own basic auth.
    # Instead, we only allow the home IP to access this service.
    import fluff_home_ips_only

    reverse_proxy http://127.0.0.1:8384 {
      header_up Host {upstream_hostport}
    }
  '';

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
}
