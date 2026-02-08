{
  config,
  lib,
  pkgs,
  username,
  tld,
  dataBaseDir,
  ...
}: let
  cfg = config.services.fluffy.ferrishare;
  configFile = pkgs.writeText "config.toml" ''
    app_name = "FluffyShare"
    interface = "0.0.0.0:3000"
    proxy_depth = 1
    # Too lazy to make this a real secret...
    admin_password_hash = "$argon2id$v=19$m=32768,t=4,p=1$oQJoVQOBFUQKMvx2y7/JTw$+hceuclY7qK+HpDN9HM80xkUUeIYzjve0Ccp8Hxrj7M"
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
in {
  options.services.fluffy.ferrishare = {
    enable = lib.mkEnableOption "Ferrishare file sharing service" // {default = true;};

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

  config = lib.mkIf cfg.enable {
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

    systemd.tmpfiles.rules = [
      "d ${dataBaseDir}/${cfg.serviceName} 0750 ${username} ${username}"
      "d ${dataBaseDir}/${cfg.serviceName}/user_templates 0750 ${username} ${username}"
      "f+ ${dataBaseDir}/${cfg.serviceName}/user_templates/legal_notice.html 0640 ${username} ${username} - nope"
      "f+ ${dataBaseDir}/${cfg.serviceName}/user_templates/privacy_policy.html 0640 ${username} ${username} - nope"
    ];

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          # https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Options
          serviceConfig = {
            Restart = "always";
            RestartSec = "100ms";
            RestartSteps = "10";
            RestartMaxDelaySec = "60s";
          };
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
              "type=bind,src=${dataBaseDir}/${cfg.serviceName},dst=/app/data"
              "type=bind,src=${configFile},dst=/config.toml,ro"
            ];
          };
        };
      };
      virtualisation.quadlet.autoEscape = true;
    };
  };
}
