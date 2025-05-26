{
  pkgs,
  lib,
  modules,
  containers,
  ...
}: let
  hostname = "cloudy";
  username = "runner";
  uid = 1000;
  tld = "test123.example.org";
  data-base-dir = "/data";
in {
  networking.hostName = hostname;

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
    ./configuration-stage0.nix

    (with modules; [
      caddy
      harden
      hetzner
      rootless-podman
      ssh
    ])

    (with containers; [
      echo
    ])

    {
      _module.args = {inherit username uid tld data-base-dir;};
    }
  ];
}
