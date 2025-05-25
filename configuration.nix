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

  imports = lib.flatten [
    (with modules; [
      hetzner
      ssh
      podman
      harden
    ])
    ./caddy.nix
  ];

  environment.systemPackages = with pkgs; [
    btop
  ];

  users.users."${username}" = {
    initialHashedPassword = "!";
    isNormalUser = true;
    uid = uid;

    # Auto start before user login.
    linger = true;
    # Required for rootless container with multiple users.
    autoSubUidGidRange = true;
  };

  systemd.tmpfiles.rules = [
    "d /data/echo2 0750 ${toString uid} ${toString uid}"
  ];

  home-manager.users."${username}" = {
    pkgs,
    config,
    ...
  }: {
    home.stateVersion = "25.05";
    home.packages = [];
    imports = [inputs.quadlet-nix.homeManagerModules.quadlet];

    # Ensure the systemd services are (re)started on config change.
    systemd.user.startServices = "sd-switch";

    virtualisation.quadlet.containers = {
      echo-server = {
        autoStart = true;
        serviceConfig = {
          RestartSec = "10";
          Restart = "always";
        };
        containerConfig = {
          image = "docker.io/mendhak/http-https-echo:31";
          publishPorts = ["127.0.0.1:9001:8080"];
          userns = "keep-id";
          mounts = ["type=bind,src=/data/echo2/,dst=/persisted-data"];
        };
      };
    };
  };
}
