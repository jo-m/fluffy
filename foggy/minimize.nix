{
  modulesPath,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/perlless.nix")
  ];

  programs.command-not-found.enable = false;

  # Disable the massive firmware blob package.
  hardware.enableRedistributableFirmware = false;
  # We want the microcode though.
  hardware.cpu.intel.updateMicrocode = true;
}
