{pkgs, ...}: {
  system.stateVersion = "26.05";
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "foggy";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false;

  environment.systemPackages = with pkgs; [
    sbctl # To generate secure boot keys.
    efitools
    fwupd
  ];

  services.fwupd.enable = true;

  imports = [
    ./foggy/disk-config.nix
    ./foggy/hardware-configuration.nix
    ./foggy/network.nix
    ./common/ssh.nix
  ];
}
