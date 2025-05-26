{...}: let
  tld = "test123.example.org";
in {
  services.caddy = {
    enable = true;
    virtualHosts."${tld}".extraConfig = ''
      encode
      respond "Hello, world!"
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
