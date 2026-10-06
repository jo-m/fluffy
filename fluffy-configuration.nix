{...}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = [
    ./fluffy-configuration-stage0.nix

    ./fluffy/backup.nix
    ./fluffy/caddy
    ./fluffy/fogdb.nix
    ./fluffy/harden.nix
    ./fluffy/monitoring.nix
    ./fluffy/options.nix
    ./fluffy/podfather.nix
    ./fluffy/prometheus-podman-exporter.nix
    ./fluffy/rootless-podman.nix
    ./fluffy/syncthing.nix
    ./fluffy/system.nix
    ./fluffy/webdav.nix

    ./fluffy/containers
  ];
}
