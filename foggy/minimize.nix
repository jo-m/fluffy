_: {
  # TODO: Once our NixOS is new enough to include https://github.com/nikstur/userborn/issues/7,
  #       we can enable it again.
  # imports = [
  #   (modulesPath + "/profiles/perlless.nix")
  # ];

  programs.command-not-found.enable = false;

  # We want the microcode though.
  hardware.cpu.intel.updateMicrocode = true;
}
