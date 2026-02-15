{
  config,
  lib,
  ...
}: let
  inherit (config.fluffy) username tld data-base-dir;
  cfg = config.services.fluffy.ferrishare;
  outerConfig = config;
  containerLib = import ./lib.nix;
in {
  options.services.fluffy.ferrishare = {
    serviceName = lib.mkOption {
      type = lib.types.str;
      description = "Systemd service name for the container";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain for Caddy reverse proxy";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Internal container port";
    };
  };

  config = {
    services.caddy.virtualHosts."${cfg.domain}.${tld}" = {
      extraConfig = ''
        encode
        # Public, no auth - thus, ratelimit.
        import fluff-global-rate-limit
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    sops.secrets."ferrishare/admin_password_hash" = {};
    sops.templates.ferrishare-config.content = ''
      app_name = "FluffyShare"
      interface = "0.0.0.0:3000"
      proxy_depth = 1
      admin_password_hash = "${outerConfig.sops.placeholder."ferrishare/admin_password_hash"}"
      # 500 MiB
      maximum_filesize = 524288000
      # 5 GiB
      maximum_quota = 5368709120
      maximum_uploads_per_ip = 5
      daily_request_limit_per_ip = 50
      log_level = "INFO"
      enable_privacy_policy = false
      enable_legal_notice = false
      demo_mode = false
    '';
    sops.templates.ferrishare-config.owner = username;

    systemd.tmpfiles.rules = [
      "d ${data-base-dir}/${cfg.serviceName} 0750 ${username} ${username}"
      "d ${data-base-dir}/${cfg.serviceName}/user_templates 0750 ${username} ${username}"
      "f+ ${data-base-dir}/${cfg.serviceName}/user_templates/legal_notice.html 0640 ${username} ${username} - nope"
      "f+ ${data-base-dir}/${cfg.serviceName}/user_templates/privacy_policy.html 0640 ${username} ${username} - nope"
    ];

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "ghcr.io/tobiasmarschner/ferrishare:1";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:3000"];
            exec = ["--config-file" "/config.toml"];
            mounts = [
              "type=bind,src=${data-base-dir}/${cfg.serviceName},dst=/app/data"
              "type=bind,src=${outerConfig.sops.templates.ferrishare-config.path},dst=/config.toml,ro"
            ];
            labels = containerLib.podfatherLabels {
              name = "Ferrishare";
              icon = "📤";
              category = "Sharing";
              description = "Public File Sharing";
              url = "https://${cfg.domain}.${tld}/";
            };
          };
        };
      };
      virtualisation.quadlet.autoEscape = true;
    };
  };
}
