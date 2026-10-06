{lib, ...}: {
  # Lanzaboote currently replaces the systemd-boot module.
  # Force this to false to overwrite stage 0.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  imports = [
    ./foggy-configuration-stage0.nix
  ];
}
