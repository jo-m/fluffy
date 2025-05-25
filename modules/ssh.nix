{pkgs, ...}: {
  services.openssh = {
    enable = true;
    allowSFTP = false;
    ports = [4721];

    # https://www.ssh-audit.com/
    settings = {
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

  services.fail2ban = {
    enable = true;
    maxretry = 10;
    bantime-increment.enable = true;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # https://github.com/jo-m.keys
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN9enr+MiM3M3w6x3e/ZNgAaK9Bznb6kHmj8i6RBUzq8"
  ];
}
