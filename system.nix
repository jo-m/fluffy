{
  modulesPath,
  lib,
  pkgs,
  ...
}: let
  username = "runner";
in {
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  services.openssh = {
    enable = true;
    allowSFTP = false;
    ports = [4721];

    # https://infosec.mozilla.org/guidelines/openssh#modern-openssh-67
    settings = {
      LogLevel = "VERBOSE";
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = true;

      KexAlgorithms = [
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group-exchange-sha256"
      ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
        "aes256-ctr"
        "aes192-ctr"
        "aes128-ctr"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
        "umac-128@openssh.com"
      ];
    };
    extraConfig = ''
      ClientAliveCountMax 0
      ClientAliveInterval 300

      AllowTcpForwarding no
      AllowAgentForwarding no
      MaxAuthTries 3
      MaxSessions 2
      TCPKeepAlive no

      PrintLastLog no
    '';
  };
  services.fail2ban.enable = true;

  # networking.firewall.allowedTCPPorts = [ 4721 ];
  # networking.useDHCP = lib.mkDefault true;

  users.users.root.openssh.authorizedKeys.keys = [
    # https://github.com/jo-m.keys
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9enr+MiM3M3w6x3e/ZNgAaK9Bznb6kHmj8i6RBUzq8"
  ];

  users.users."${username}" = {
    initialHashedPassword = "!";
    isNormalUser = true;
    description = username;
    packages = with pkgs; [];
  };

  environment.systemPackages = map lib.lowPrio [
    # pkgs.curl
    # pkgs.gitMinimal
  ];

  system.stateVersion = "25.05";
}
