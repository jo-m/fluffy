{...}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = [
    ./configuration-stage0.nix

    ./modules/backup.nix
    ./modules/caddy
    ./modules/harden.nix
    ./modules/hetzner
    ./modules/monitoring.nix
    ./modules/options.nix
    ./modules/podfather.nix
    ./modules/rootless-podman.nix
    ./modules/ssh.nix
    ./modules/syncthing.nix
    ./modules/webdav.nix

    ./containers
  ];
}
