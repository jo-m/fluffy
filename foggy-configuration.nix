{...}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = [
    ./foggy-configuration-stage0.nix

    ./common/harden.nix
    ./common/options.nix
    ./common/prometheus-podman-exporter.nix
    ./common/system.nix
    ./common/rootless-podman.nix

    ./foggy/minimize.nix
    ./foggy/fwupd.nix
  ];
}
