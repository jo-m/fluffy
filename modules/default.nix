{
  backup = import ./backup.nix;
  caddy = import ./caddy.nix;
  harden = import ./harden.nix;
  hetzner = import ./hetzner;
  opentelemetry-collector = import ./opentelemetry-collector.nix;
  rootless-podman = import ./rootless-podman.nix;
  ssh = import ./ssh.nix;
  syncthing = import ./syncthing.nix;
  webdav = import ./webdav.nix;
}
