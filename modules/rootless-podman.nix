{
  inputs,
  username,
  uid,
  ...
}: {
  networking.firewall.interfaces."podman+".allowedUDPPorts = [53];

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
    uid = uid;

    # Auto start before user login.
    linger = true;
    # Required for rootless container with multiple users.
    autoSubUidGidRange = true;
  };

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
  };
}
