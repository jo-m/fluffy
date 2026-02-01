{
  backup = import ./backup.nix;
  caddy = import ./caddy;
  harden = import ./harden.nix;
  hetzner = import ./hetzner;
  monitoring = import ./monitoring.nix;
  rootless-podman = import ./rootless-podman.nix;
  ssh = import ./ssh.nix;
  syncthing = import ./syncthing.nix;
  webdav = import ./webdav.nix;
}
