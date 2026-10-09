{
  modulesPath,
  lib,
  config,
  ...
}: let
  inherit (config.custom) username;
in {
  # TODO: Once our NixOS is new enough to include https://github.com/nikstur/userborn/issues/7,
  #       we can enable it again.
  # imports = [
  #   (modulesPath + "/profiles/perlless.nix")
  # ];

  programs.command-not-found.enable = false;

  # Disable the massive firmware blob package.
  hardware.enableRedistributableFirmware = false;
  # We want the microcode though.
  hardware.cpu.intel.updateMicrocode = true;
}
