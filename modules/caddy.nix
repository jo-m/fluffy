{...}: let
  tld = "test123.example.org";
in {
  services.caddy = {
    enable = true;
    # TODO: Remove, or replace with welcome page.
    virtualHosts."${tld}".extraConfig = ''
      encode
      respond "Hello, world!"
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
