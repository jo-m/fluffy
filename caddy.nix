{...}: {
  services.caddy = {
    enable = true;
    virtualHosts."test123.example.org".extraConfig = ''
      encode
      respond "Hello, world!"
    '';
    virtualHosts."echo.test123.example.org".extraConfig = ''
      encode
      reverse_proxy http://127.0.0.1:9001
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
