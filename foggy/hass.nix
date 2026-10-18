{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.custom) username data-base-dir domain;
  cfg = config.custom.hass;
in {
  options.custom.hass = {
    port = lib.mkOption {
      type = lib.types.port;
      description = "Internal port";
      default = 8123;
    };

    externalPort = lib.mkOption {
      type = lib.types.port;
      description = "Internal port";
      default = 11443;
    };
  };

  config = {
    services.podfather.external-apps.HASS = {
      name = "Home Assistant";
      icon = "🏠";
      category = "Infrastructure";
      description = "Smart Home";
      url = "https://${domain}:${toString cfg.externalPort}/";
    };

    services.caddy.virtualHosts."${domain}:${toString cfg.externalPort}" = {
      extraConfig = ''
        bind ${config.services.foggy.caddy.bindIP}
        tls internal
        encode
        reverse_proxy http://[::1]:${toString cfg.port}
      '';
      logFormat = ''
        output stderr
      '';
    };

    networking.firewall.allowedTCPPorts = [cfg.externalPort];

    services.home-assistant = {
      enable = true;
      extraComponents = [
        "bthome"
        "roborock"

        # Recommended for fast zlib compression
        # https://www.home-assistant.io/integrations/isal
        "isal"

        # Components required to complete the onboarding.
        "analytics"
        "google_translate"
        "radio_browser"
        "shopping_list"
        "met"
      ];
      config = {
        # Includes dependencies for a basic setup
        # https://www.home-assistant.io/integrations/default_config/
        default_config = {};
        http = {
          server_port = cfg.port;
          server_host = "::1";
          trusted_proxies = ["::1"];
          use_x_forwarded_for = true;
        };

        name = "Home";
        longitude = 8.54;
        latitude = 47.37;
        elevation = "420";
        unit_system = "metric";
        time_zone = "Europe/Zurich";
      };
    };
  };
}
