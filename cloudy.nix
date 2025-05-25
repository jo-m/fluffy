{
  lib,
  pkgs,
  hostname,
  modules,
  inputs,
  modulesPath,
  home-manager,
  ...
}: let
  username = "runner";
in {
  system.stateVersion = "25.05";
  networking.hostName = hostname;
  nixpkgs.hostPlatform = "x86_64-linux";

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  imports = lib.flatten [
    (with modules; [
      hetzner
      ssh
    ])
    # home-manager.nixosModules.home-manager
    # ../../services/monitoring.nix
    # ./headscale.nix
    # ./proxy.nix
    # ./nginx.nix
    # ./kanidm.nix
  ];

  # networking.firewall.allowedTCPPorts = [ 4721 ];
  # networking.useDHCP = lib.mkDefault true;

  environment.systemPackages = map lib.lowPrio [
    # pkgs.curl
    # pkgs.gitMinimal
  ];

  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings = {
      # Required for container networking to be able to use names.
      dns_enabled = true;
    };
  };

  users.users."${username}" = {
    initialHashedPassword = "!";
    isNormalUser = true;

    # required for auto start before user login
    linger = true;
    # required for rootless container with multiple users
    autoSubUidGidRange = true;
  };

  # home-manager.nixosModules.home-manager {}

  # home-manager.users."${username}" = {
  #   pkgs,
  #   config,
  #   ...
  # }: {
  #   imports = [inputs.quadlet-nix.homeManagerModules.quadlet];
  #   # This is crucial to ensure the systemd services are (re)started on config change
  #   systemd.user.startServices = "sd-switch";
  #   virtualisation.quadlet.containers = {
  #     echo-server = {
  #       autoStart = true;
  #       serviceConfig = {
  #         RestartSec = "10";
  #         Restart = "always";
  #       };
  #       containerConfig = {
  #         image = "docker.io/mendhak/http-https-echo:31";
  #         publishPorts = ["127.0.0.1:8080:8080"];
  #         userns = "keep-id";
  #       };
  #     };
  #   };
  # };
}
