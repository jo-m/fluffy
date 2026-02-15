{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.fluffy) username tld;
  cfg = config.fluffy.podfather;

  # Convert external-apps attrset to PODFATHER_APP_<KEY>_<FIELD> env var list.
  externalAppEnvVars = lib.concatLists (lib.mapAttrsToList (key: app: let
    prefix = "PODFATHER_APP_${key}";
    mkVar = field: value: "\"${prefix}_${field}=${value}\"";
    optionalVar = field: value:
      if value != null
      then [(mkVar field value)]
      else [];
  in
    [(mkVar "NAME" app.name)]
    ++ optionalVar "ICON" app.icon
    ++ optionalVar "CATEGORY" app.category
    ++ optionalVar "SORT_INDEX" app.sort-index
    ++ optionalVar "DESCRIPTION" app.description
    ++ optionalVar "URL" app.url)
  cfg.external-apps);
in {
  options.fluffy.podfather = {
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port for the Podfather web dashboard";
      default = 30120;
    };

    base-path = lib.mkOption {
      type = lib.types.str;
      description = "Base path for reverse proxy subpath hosting";
      default = "";
    };

    podman-socket = lib.mkOption {
      type = lib.types.str;
      description = "Path to the Podman API socket";
      default = "%t/podman/podman.sock";
    };

    external-apps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name of the app";
          };
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Emoji icon for the app";
            default = null;
          };
          category = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Category grouping";
            default = null;
          };
          sort-index = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Sort index within category";
            default = null;
          };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Short description of the app";
            default = null;
          };
          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "URL of the app";
            default = null;
          };
        };
      });
      description = "External (non-container) apps to register in the Podfather dashboard";
      default = {};
    };
  };

  config = {
    services.caddy.virtualHosts."${tld}" = {
      extraConfig = ''
        encode
        authorize with fluff-auth-policy
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      logFormat = "output stderr";
    };

    home-manager.users."${username}" = _: {
      systemd.user.services.podfather = {
        Unit = {
          Description = "Simple podman web dashboard";
          Requires = ["podman.socket"];
          After = ["podman.socket"];
        };
        Service = {
          ExecStart = "${pkgs.podfather}/bin/podfather";
          Environment =
            [
              "LISTEN_ADDR=127.0.0.1:${toString cfg.port}"
              "PODMAN_SOCKET=${cfg.podman-socket}"
              "BASE_PATH=${cfg.base-path}"
              # For triggering `podman auto-update`.
              "PATH=${pkgs.podman}/bin"
              "ENABLE_AUTOUPDATE_BUTTON=true"
            ]
            ++ externalAppEnvVars;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };
    };
  };
}
