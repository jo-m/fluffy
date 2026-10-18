{config, ...}: {
  sops.defaultSopsFile = ./secrets-foggy.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  custom.domain = "${config.networking.hostName}.local";

  hardware.bluetooth.enable = true;
  custom.prometheus-bthome-exporter.enable = true;

  services.wireguard = {
    address = "10.99.0.2";
    peer-address = "10.99.0.1";
    peer-public-key-secret = "wireguard/fluffy-pubkey_unencrypted";
    peer-endpoint = "${builtins.getEnv "REMOTE_DOMAIN"}:39277";
  };

  services.prometheus = {
    retentionTime = "5y";
    extraFlags = ["--storage.tsdb.retention.size=20GB"];
  };

  # The onboard Bluetooth radio needs firmware for the BTHome exporter.
  hardware.enableRedistributableFirmware = true;

  imports = [
    ./foggy-configuration-stage0.nix

    ./common/backup.nix
    ./common/harden.nix
    ./common/monitoring.nix
    ./common/options.nix
    ./common/podfather.nix
    ./common/prometheus-bthome-exporter.nix
    ./common/prometheus-podman-exporter.nix
    ./common/rootless-podman.nix
    ./common/system.nix
    ./common/wireguard.nix

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
