_: {
  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "fluffy";

  imports = [
    ./fluffy/disk-config.nix
    ./fluffy/hetzner.nix
    ./common/ssh.nix
  ];
}
