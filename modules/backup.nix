{
  inputs,
  config,
  dataBaseDir,
  lib,
  pkgs,
  ...
}: let
  username = "backup";
  jobName = "data";
in {
  users.users."${username}" = {
    initialHashedPassword = "!";
    isNormalUser = true;
    group = "users";

    # This gives the backup user RO access to (almost) everything in `/data`.
    extraGroups = ["runner" "caddy"];
  };

  sops.secrets."borg-backup/ssh-key-priv".mode = "0400";
  sops.secrets."borg-backup/ssh-key-priv".owner = config.users.users."${username}".name;

  sops.secrets."borg-backup/repo-passphrase".mode = "0400";
  sops.secrets."borg-backup/repo-passphrase".owner = config.users.users."${username}".name;

  sops.secrets."borg-backup/repo" = {};
  sops.templates.borg-repo.content = "BORG_REPO=${config.sops.placeholder."borg-backup/repo"}";
  sops.templates.borg-repo.owner = username;

  sops.secrets."borg-backup/repo-hostkeys".mode = "0444";
  sops.secrets."borg-backup/repo-hostkeys".owner = "root";
  programs.ssh.extraConfig = ''
    GlobalKnownHostsFile ${config.sops.secrets."borg-backup/repo-hostkeys".path}
  '';

  # Start and monitor manually:
  #   systemctl start borgbackup-job-data.service
  #   journalctl -fu borgbackup-job-data.service
  services.borgbackup.jobs."${jobName}" = {
    user = config.users.users."${username}".name;
    paths = dataBaseDir;
    exclude = [
      "${dataBaseDir}/syncthing"
      "${dataBaseDir}/lost+found"
      "${dataBaseDir}/readeck/config.toml"
    ];
    extraCreateArgs = "--verbose --stats";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets."borg-backup/repo-passphrase".path}";
    };
    environment = {
      BORG_RSH = "ssh -i ${config.sops.secrets."borg-backup/ssh-key-priv".path}";
      BORG_REMOTE_PATH = "borg1";
    };
    compression = "auto,zstd";
    startAt = "03:00";
    prune.keep = {
      within = "1d"; # Keep all archives from the last day
      daily = 7;
      weekly = 8;
      monthly = 12;
      yearly = 5;
    };
    repo = ""; # We set this below instead.
  };

  # Manually override some stuff which services.borgbackup.jobs does not expose.
  systemd.services."borgbackup-job-${jobName}".serviceConfig = {
    # Set the repo via EnvironmentFile because we treat it as a secret.
    EnvironmentFile = config.sops.templates.borg-repo.path;
    # Do not set a group in the unit file, run with all the groups the user is a member of.
    Group = lib.mkForce null;
    # Manually set up as ExecStartPre with + because needs to run as root.
    ExecStartPre = let
      script = pkgs.writeShellScript "copy-grafana-db" ''
        ${pkgs.sqlite}/bin/sqlite3 /var/lib/grafana/data/grafana.db ".backup '/data/grafana.db'"
      '';
    in "+${script}";
  };

  # Periodic monitoring job to check backup status
  systemd.services."backup-status-check" = {
    description = "Check backup job status";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = let
        script = pkgs.writeShellScript "check-backup-status" ''
          systemctl show borgbackup-job-${jobName}.service --property=Result
        '';
      in "${script}";
    };
  };

  systemd.timers."backup-status-check" = {
    description = "Timer for backup status check";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
    };
  };
}
