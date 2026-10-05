_: {
  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = [
    ./fluffy/hetzner
    ./fluffy/ssh.nix
  ];
}
