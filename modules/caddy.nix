{
  tld,
  config,
  ...
}: {
  sops.secrets."caddy/basicauth" = {};
  sops.templates.caddy-top-level-basic-auth.content = ''
    (top_level_basic_auth) {
      basic_auth {
        ${config.sops.placeholder."caddy/basicauth"}
      }
    }
  '';
  sops.templates.caddy-top-level-basic-auth.owner = "caddy";

  services.caddy = {
    enable = true;
    # TODO: Remove, or replace with welcome page.
    virtualHosts."${tld}".extraConfig = ''
      respond "Hello, world!"
    '';

    extraConfig = ''
      # Import basic auth config file.
      import ${config.sops.templates.caddy-top-level-basic-auth.path}
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
