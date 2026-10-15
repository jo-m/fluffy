{config, ...}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  custom.domain = "${config.networking.hostName}.local";

  imports = [
    ./foggy-configuration-stage0.nix

    ./common/harden.nix
    ./common/monitoring.nix
    ./common/options.nix
    ./common/podfather.nix
    ./common/prometheus-podman-exporter.nix
    ./common/rootless-podman.nix
    ./common/system.nix

    ./foggy/caddy.nix
    ./foggy/fogdb.nix
    ./foggy/fwupd.nix
    ./foggy/minimize.nix
    ./foggy/monitoring-grafana.nix
    ./foggy/network.nix
    ./foggy/syncthing.nix

    ./foggy/containers
  ];
}
