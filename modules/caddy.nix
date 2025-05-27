{tld, ...}: {
  services.caddy = {
    enable = true;
    # TODO: Remove, or replace with welcome page.
    virtualHosts."${tld}".extraConfig = ''
      respond "Hello, world!"
    '';

    # TODO: Use real secret
    # TODO: rename mybasicauth
    extraConfig = ''
      (mybasicauth) {
        basic_auth {
          # Username "Bob", password "hiccup"
          Bob $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
        }
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
