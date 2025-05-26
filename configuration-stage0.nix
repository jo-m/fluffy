{
  pkgs,
  lib,
  modules,
  containers,
  ...
}: {
  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = lib.flatten [
    (with modules; [
      hetzner
      ssh
    ])
  ];
}
