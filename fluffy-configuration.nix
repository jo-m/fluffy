{...}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = [
    ./fluffy-configuration-stage0.nix

    ./common/harden.nix
    ./common/monitoring.nix
    ./common/options.nix
    ./common/podfather.nix
    ./common/prometheus-podman-exporter.nix
    ./common/rootless-podman.nix
    ./common/system.nix

    ./fluffy/backup.nix
    ./fluffy/caddy.nix
    ./fluffy/fogdb.nix
    ./fluffy/monitoring-grafana.nix
    ./fluffy/syncthing.nix
    ./fluffy/webdav.nix

    ./fluffy/containers
  ];
}
