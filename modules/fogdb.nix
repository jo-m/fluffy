# FogDB: long-running ingester for MeteoSwiss point forecasts into a local
# SQLite archive. Runs as a system service under the primary unprivileged user.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.fluffy) username data-base-dir;
  serviceName = "fogdb";
  dataDir = "${data-base-dir}/${serviceName}";
  dbPath = "${dataDir}/db.sqlite";
in {
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 ${username} ${username}"
  ];

  systemd.services."${serviceName}" = {
    description = "FogDB MeteoSwiss point-forecast ingester";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    serviceConfig = {
      Type = "simple";
      User = username;
      Group = username;
      ExecStart = "${lib.getExe pkgs.fogdb} --db ${dbPath}";
      Restart = "on-failure";
      RestartSec = 30;
      UMask = "0027";

      # Hardening: this is a stateless ingester that only needs network egress
      # and write access to its own data directory.
      ReadWritePaths = [dataDir];
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
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    };
  };
}
