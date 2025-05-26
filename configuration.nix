{
  config,
  pkgs,
  lib,
  modulesPath,
  modules,
  inputs,
  outputs,
  hostname,
  ...
}: let
  username = "runner";
  uid = 1000;
in {
  system.stateVersion = "25.05";
  networking.hostName = hostname;
  nixpkgs.hostPlatform = "x86_64-linux";

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  services.journald.extraConfig = "SystemMaxUse=500M";

  boot.kernel.sysctl = {
    "vm.swappiness" = 25;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "delete-older-than 7d";
      persistent = false;
    };

    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
  };

  environment.systemPackages = with pkgs; [
    btop
  ];

  imports = lib.flatten [
    (with modules; [
      caddy
      harden
      hetzner
      rootless-podman
      ssh
    ])
    ./containers/echo.nix
  ];
}
