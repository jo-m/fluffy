{
  modulesPath,
  lib,
  pkgs,
  ...
}: {
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    extraConfig = ''
      PrintLastLog no
    '';
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # https://github.com/jo-m.keys
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9enr+MiM3M3w6x3e/ZNgAaK9Bznb6kHmj8i6RBUzq8"
  ];

  environment.systemPackages = map lib.lowPrio [
    # pkgs.curl
    # pkgs.gitMinimal
  ];

  system.stateVersion = "25.05";
}
