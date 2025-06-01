{
  pkgs,
  lib,
  modules,
  containers,
  ...
}: let
  hostname = "fluffy";
  username = "runner";
  uid = 1000;
  tld = "${hostname}.example.net";
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

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  imports = lib.flatten [
    ./configuration-stage0.nix

    (with modules; [
      caddy
      harden
      hetzner
      rootless-podman
      ssh
      syncthing
    ])

    (with containers; [
      echo
    ])

    {
      _module.args = {inherit username uid tld data-base-dir;};
    }
  ];
}
