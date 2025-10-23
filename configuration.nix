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
  tld = builtins.getEnv "REMOTE_TLD";
  data-base-dir = "/data";
in {
  networking.hostName = hostname;

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  services.journald.extraConfig = "SystemMaxUse=1G";

  boot.kernel.sysctl = {
    "vm.swappiness" = 25;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 30d";
      persistent = false;
    };

    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    sqlite-interactive
  ];

  environment.shellAliases = {
    l = "ls -luh";
  };

  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  imports = lib.flatten [
    ./configuration-stage0.nix

    (with modules; [
      backup
      caddy
      harden
      hetzner
      monitoring
      rootless-podman
      ssh
      syncthing
      webdav
    ])

    (with containers; [
      echo
      ferrishare
      hemmelig
      homer
      kitchenowl
      qr
      readeck
      traggo
    ])

    {
      # This is considered bad practice but I couldn't care less.
      _module.args = {inherit username uid tld data-base-dir hostname;};
    }
  ];
}
