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

  virtualisation.containers.containersConf.settings = {
    # https://github.com/containers/common/blob/main/docs/containers.conf.5.md
    containers = {
      log_driver = "journald";
    };
  };

  users.groups."${username}" = {
    gid = uid;
  };

  users.users."${username}" = {
    initialHashedPassword = "!";
    isNormalUser = true;
    inherit uid;
    group = username;
    extraGroups = ["users"];

    # Auto start before user login.
    linger = true;
    # Required for rootless container with multiple users.
    autoSubUidGidRange = true;
  };

  virtualisation.quadlet = {
    enable = true;
    autoUpdate.enable = true;
  };

  home-manager.users."${username}" = {...}: {
    home.stateVersion = "25.05";
    home.packages = [];
    imports = [inputs.quadlet-nix.homeManagerModules.quadlet];

    virtualisation.quadlet.autoUpdate.enable = true;

    # Ensure the systemd services are (re)started on config change.
    systemd.user.startServices = "sd-switch";
  };
}
