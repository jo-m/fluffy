{...}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = [
    ./fluffy-configuration-stage0.nix

    ./common/harden.nix
    ./common/options.nix
    ./common/system.nix

    ./fluffy/backup.nix
    ./fluffy/caddy.nix
    ./fluffy/fogdb.nix
    ./fluffy/monitoring.nix
    ./fluffy/podfather.nix
    ./fluffy/prometheus-podman-exporter.nix
    ./fluffy/rootless-podman.nix
    ./fluffy/syncthing.nix
    ./fluffy/webdav.nix

    ./fluffy/containers
  ];
}
