# Prometheus exporter for BTHome BLE sensors.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.prometheus-bthome-exporter;
  bindkeyCredential = "bindkey";
in {
  options.custom.prometheus-bthome-exporter = {
    enable = lib.mkEnableOption "the Prometheus BTHome BLE exporter";

    listen-address = lib.mkOption {
      type = lib.types.str;
      description = "Address the metrics HTTP server listens on.";
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Port the metrics HTTP server listens on.";
      default = 20006;
    };

    bindkey-file = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = ''
        File containing a 16-byte AES-CCM bindkey as 32 hex characters, used
        to decrypt encrypted BTHome packets. The key is applied to all devices.
      '';
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hardware.bluetooth.enable;
        message = "custom.prometheus-bthome-exporter requires hardware.bluetooth.enable.";
      }
    ];

    environment.systemPackages = [pkgs.prometheus-bthome-exporter];

    systemd.services.prometheus-bthome-exporter = {
      description = "Prometheus exporter for BTHome BLE sensors";
      wantedBy = ["multi-user.target"];
      after = ["bluetooth.service"];
      wants = ["bluetooth.service"];

      serviceConfig = {
        DynamicUser = true;
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe pkgs.prometheus-bthome-exporter)
            "--listen-address"
            cfg.listen-address
            "--port"
            (toString cfg.port)
          ]
          ++ lib.optionals (cfg.bindkey-file != null) [
            "--bindkey-file"
            "/run/credentials/prometheus-bthome-exporter/${bindkeyCredential}"
          ]
        );
        LoadCredential = lib.optionals (cfg.bindkey-file != null) [
          "${bindkeyCredential}:${cfg.bindkey-file}"
        ];
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0027";

        # Hardening: the exporter only needs the BlueZ D-Bus socket and its
        # loopback HTTP listener.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
      };
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "bthome";
        static_configs = [
          {
            targets = ["${cfg.listen-address}:${toString cfg.port}"];
          }
        ];
      }
    ];
  };
}
