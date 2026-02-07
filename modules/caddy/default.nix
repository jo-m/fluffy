{
  tld,
  config,
  pkgs,
  ...
}: let
  authPortalSubdomain = "auth";
in {
  sops.secrets."caddy/global-basicauth" = {};
  sops.templates.caddy-global-basicauth.content = ''
    (fluff_global_basicauth) {
      basic_auth {
        ${config.sops.placeholder."caddy/global-basicauth"}
      }
    }
  '';
  sops.templates.caddy-global-basicauth.owner = "caddy";

  sops.secrets."caddy/home-ips" = {};
  sops.templates.caddy-home-ips.content = ''
    (fluff_home_ips_only) {
      @denied not remote_ip ${config.sops.placeholder."caddy/home-ips"}
      abort @denied
    }
  '';
  sops.templates.caddy-home-ips.owner = "caddy";

  sops.secrets."caddy/local-users" = {};
  sops.templates.caddy-local-users.content = ''
    ${config.sops.placeholder."caddy/local-users"}
  '';
  sops.templates.caddy-local-users.owner = "caddy";

  sops.secrets."caddy/env-file" = {};
  sops.templates.caddy-env-file.content = ''
    ${config.sops.placeholder."caddy/env-file"}
  '';
  sops.templates.caddy-env-file.owner = "caddy";

  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [
        # To update: Put entire git rev after @, build, correct version will be in the error message.
        # https://github.com/mholt/caddy-ratelimit
        "github.com/mholt/caddy-ratelimit@v0.1.1-0.20250915152450-04ea34edc0c4"
        # https://github.com/mholt/caddy-webdav
        "github.com/mholt/caddy-webdav@v0.0.0-20250805175825-7a5c90d8bf90"
        # https://github.com/greenpau/caddy-security
        "github.com/greenpau/caddy-security@v1.1.31"
      ];
      hash = "sha256-8rmrjEMgGihbuA7tT63Wr4B9AoMerHeVEQzxMXhrG1o=";
    };

    environmentFile = config.sops.templates.caddy-env-file.path;

    globalConfig = ''
      metrics{
        per_host
      }

      order authenticate before respond
      order authorize before basicauth

      security {
        local identity store fluff_auth_db {
          realm local
          path {$HOME}/.local/share/caddy/users.json
          import ${config.sops.templates.caddy-local-users.path}
        }

        authentication portal fluff_auth_portal {
          crypto default token lifetime 172800 # 48 h
          crypto key sign-verify {env.JWT_SHARED_SECRET}
          crypto key token name fluff_auth

          enable identity store fluff_auth_db

          cookie domain ${tld}
          # See https://github.com/greenpau/caddy-security/issues/58.
          cookie lifetime 31536000

          ui {
            theme basic

            static_asset "assets/images/favicon.png" "image/png" ${./cloud.png}
            logo url "/assets/images/favicon.png"
            logo description "Logo"

            links {
              "Portal" https://${tld}/ icon "las la-star"
              "Whoami" "/whoami" icon "las la-user"
            }
          }

          transform user {
            match origin local
            action add role authp/user
            action add role authp/admin
          }
        }

        authorization policy fluff_internal_auth {
          set auth url https://${authPortalSubdomain}.${tld}

          crypto key verify {env.JWT_SHARED_SECRET}
          crypto key token name fluff_auth

          set user identity email

          acl rule {
            comment Allow users only
            match role fluff-user
            allow stop log info
          }

          inject headers with claims
        }
      }
    '';

    extraConfig = ''
      # Import config files with secrets.
      import ${config.sops.templates.caddy-global-basicauth.path}
      import ${config.sops.templates.caddy-home-ips.path}

      ${builtins.readFile ./fluff_global_rate_limit.Caddyfile}
    '';

    # Auth portal vhost.
    virtualHosts."${authPortalSubdomain}.${tld}" = {
      extraConfig = ''
        encode
        authenticate with fluff_auth_portal
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };
  };

  networking.firewall.allowedTCPPorts = [80 443];
}
