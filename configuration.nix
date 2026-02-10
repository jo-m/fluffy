{
  lib,
  modules,
  ...
}: {
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = lib.flatten [
    ./configuration-stage0.nix

    (with modules; [
      backup
      caddy
      harden
      hetzner
      monitoring
      options
      rootless-podman
      ssh
      syncthing
      webdav
    ])

    # Import all container modules.
    (import ./containers)
  ];
}
