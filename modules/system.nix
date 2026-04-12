{pkgs, ...}: {
  networking.hostName = "fluffy";

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  services.journald.extraConfig = "SystemMaxUse=1G";

  boot.kernel.sysctl = {
    "vm.swappiness" = 25;
  };

  # Try to save some space.
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 5d";
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
    duf
    jq
  ];

  environment.shellAliases = {
    l = "ls -luh";
  };
}
