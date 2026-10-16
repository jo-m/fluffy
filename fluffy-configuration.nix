{...}: {
  sops.defaultSopsFile = ./secrets-fluffy.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  services.wireguard = {
    address = "10.99.0.1";
    peer-address = "10.99.0.2";
    peer-public-key-secret = "wireguard/foggy-pubkey_unencrypted";
    listen-port = 39277;
  };

  imports = [
    ./fluffy-configuration-stage0.nix

    ./common/harden.nix
    ./common/monitoring.nix
    ./common/options.nix
    ./common/podfather.nix
    ./common/prometheus-podman-exporter.nix
    ./common/rootless-podman.nix
    ./common/system.nix
    ./common/wireguard.nix

    ./fluffy/backup.nix
    ./fluffy/caddy.nix
    ./fluffy/monitoring-grafana.nix
    ./fluffy/syncthing.nix
    ./fluffy/webdav.nix

    ./fluffy/containers
  ];
}
