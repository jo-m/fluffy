{
  inputs,
  config,
  data-base-dir,
  lib,
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
  # TODO: Does not work.
  # programs.ssh.knownHostsFiles = [config.sops.secrets."borg-backup/repo-hostkeys".path];

  # Start and monitor manually:
  #   systemctl start borgbackup-job-data.service
  #   journalctl -fu borgbackup-job-data.service
  services.borgbackup.jobs."${jobName}" = {
    user = config.users.users."${username}".name;
    paths = data-base-dir;
    exclude = [
      "${data-base-dir}/syncthing"
      "${data-base-dir}/lost+found"
      "${data-base-dir}/readeck/config.toml"
    ];
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets."borg-backup/repo-passphrase".path}";
    };
    environment = {
      # TODO: Get rid of StrictHostKeyChecking.
      BORG_RSH = "ssh -o StrictHostKeyChecking=no -i ${config.sops.secrets."borg-backup/ssh-key-priv".path}";
      BORG_REMOTE_PATH = "borg1";
    };
    compression = "auto,zstd";
    startAt = "daily";
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
  };
}
