{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.custom) username data-base-dir domain;
  cfg = config.services.foggy.teddycloud;
  wireguard = config.services.wireguard;
  containerLib = import ../../common/containers-lib.nix;
  externalPort = 8443;

  # pasta copies the host addresses and routes into the container netns exactly
  # once, when the container starts (pasta --config-net). systemd-networkd
  # reports the link as online once it has carrier and the static address,
  # which is before DHCP has installed the default route. If podman starts the
  # container in that window, the netns ends up without a default route and the
  # container has no egress until restarted.
  waitForDefaultRoute = pkgs.writeShellApplication {
    name = "wait-for-default-route";
    runtimeInputs = [pkgs.iproute2];
    text = ''
      waited=0
      until [ -n "$(ip -4 route show default)" ]; do
        if [ "$waited" -ge 600 ]; then
          echo "no IPv4 default route after 600s; giving up" >&2
          exit 1
        fi
        sleep 1
        waited=$((waited + 1))
      done
    '';
  };
in {
  options.services.foggy.teddycloud = {
    serviceName = lib.mkOption {
      type = lib.types.str;
      description = "Systemd service name for the container";
      default = "teddycloud";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Host port to publish the web UI on, both on localhost and the WireGuard address";
    };

    tonieApiAddr = lib.mkOption {
      type = lib.types.str;
      description = "Public IP address teddycloud will listen on";
      default = "10.0.0.13";
    };
  };

  config = {
    services.caddy.virtualHosts."${domain}:${toString externalPort}" = {
      extraConfig = ''
        bind ${config.services.foggy.caddy.bindIP}
        tls internal
        encode
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      logFormat = ''
        output stderr
      '';
    };

    networking.firewall.allowedTCPPorts = [443 externalPort];
    # Only the tunnel partner may reach the web UI port directly (the LAN uses Caddy on :8443).
    networking.firewall.interfaces."${wireguard.iface}".allowedTCPPorts = [cfg.port];

    # Allow unprivileged users to listen on :443.
    boot.kernel.sysctl = {
      "net.ipv4.ip_unprivileged_port_start" = 443;
    };

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
    ];

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          serviceConfig =
            containerLib.ServiceConfig
            // {
              ExecStartPre = lib.getExe waitForDefaultRoute;
            };
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "ghcr.io/toniebox-reverse-engineering/teddycloud:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            podmanArgs = ["--umask=0027"];
            publishPorts = [
              "127.0.0.1:${toString cfg.port}:80" # Web interface.
              "${wireguard.address}:${toString cfg.port}:80" # Web interface, for fluffy's Caddy over the tunnel.
              "${cfg.tonieApiAddr}:443:443" # API, needs to directly expose port 443 on static IP.
            ];
            mounts = [
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/certs,dst=/teddycloud/certs" # certificates of the server
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/config,dst=/teddycloud/config" # config file for the server and the boxes
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/content,dst=/teddycloud/data/content" # microSD representation for the boxes
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/library,dst=/teddycloud/data/library" # library to manage content
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/custom_img,dst=/teddycloud/data/www/custom_img" # location to store custom images for custom tonies json
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/firmware,dst=/teddycloud/data/firmware" # firmware backups
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/cache,dst=/teddycloud/data/cache" # img cache for content images
              "type=bind,src=${data-base-dir}/${cfg.serviceName}/plugins,dst=/teddycloud/data/www/plugins" # location to store web plugins for teddyCloud
            ];
            labels = containerLib.podfatherLabels {
              name = "Teddycloud";
              icon = "🧸";
              category = "Apps";
              url = "https://${domain}:${toString externalPort}";
            };
          };
        };
      };
    };
  };
}
