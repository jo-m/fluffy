{...}: {
  services.caddy = {
    enable = true;
    virtualHosts."test123.example.org".extraConfig = ''
      encode
      respond "Hello, world!"
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
