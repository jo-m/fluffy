{
  config,
  lib,
  pkgs,
  username,
  tld,
  ...
}: let
  cfg = config.services.fluffy.homer;
  containerLib = import ./lib.nix;
  configFile = pkgs.writeText "homer.yaml" ''
    ---
    # https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md

    # For local development:
    #
    #   docker run \
    #     -p 8080:8080 \
    #     --mount type=bind,source=(pwd)/homer.yaml,target=/www/assets/config.yml \
    #     b4bz/homer:latest

    title: "Fluffy Cloud"
    subtitle: "Home"
    # https://fontawesome.com/search
    icon: "fas fa-cloud-showers-heavy"

    header: true
    footer: false

    columns: "3" # "auto" or number (must be a factor of 12: 1, 2, 3, 4, 6, 12)
    connectivityCheck: true

    # Optional: Proxy / hosting option
    proxy:
      useCredentials: false # send cookies & authorization headers when fetching service specific data. Set to `true` if you use an authentication proxy. Can be overrided on service level.
      headers: # send custom headers when fetching service specific data. Can also be set on a service level.
        Test: "Example"
        Test1: "Example1"

    # https://github.com/bastienwirtz/homer/tree/main/src/assets/themes
    theme: neon # default, neon, walkxcode

    # Here is the exhaustive list of customization parameters
    # However all value are optional and will fallback to default if not set.
    # if you want to change only some of the colors, feel free to remove all unused key.
    colors:
      light:
        highlight-primary: "#3367d6"
        highlight-secondary: "#4285f4"
        highlight-hover: "#5a95f5"
        background: "#f5f5f5"
        card-background: "#ffffff"
        text: "#363636"
        text-header: "#424242"
        text-title: "#303030"
        text-subtitle: "#424242"
        card-shadow: rgba(0, 0, 0, 0.1)
        link: "#3273dc"
        link-hover: "#363636"
        background-image: "/assets/your/light/bg.png" # prefix with your sub subpath if any (ex: /homer/assets/...)
      dark:
        highlight-primary: "#3367d6"
        highlight-secondary: "#4285f4"
        highlight-hover: "#5a95f5"
        background: "#131313"
        card-background: "#2b2b2b"
        text: "#eaeaea"
        text-header: "#ffffff"
        text-title: "#fafafa"
        text-subtitle: "#f5f5f5"
        card-shadow: rgba(0, 0, 0, 0.4)
        link: "#3273dc"
        link-hover: "#ffdd57"
        background-image: "/assets/your/dark/bg.png" # prefix with your sub subpath if any (ex: /homer/assets/...)

    # Navbar
    links:
      - name: "Source"
        icon: "fab fa-github"
        url: "https://github.com/jo-m/fluffy"
        target: "_blank"

    # Services
    services:
      - name: "Apps"
        icon: "fas fa-house-chimney"
        items:
          - name: "Kitchenowl"
            subtitle: "Groceries & Recipes"
            icon: "fas fa-utensils"
            url: "https://kitchen.${tld}/"
            target: "_blank"
          - name: "Readeck"
            subtitle: "Bookmarks"
            icon: "fas fa-bookmark"
            url: "https://readeck.${tld}/"
            target: "_blank"
          - name: "Traggo"
            subtitle: "Time Tracking"
            icon: "fas fa-stopwatch"
            url: "https://track.${tld}/"
            target: "_blank"
          - name: "Syncthing GUI"
            subtitle: "Only from home IP"
            icon: "fas fa-rotate"
            url: "https://sync.${tld}/"
            target: "_blank"
      - name: "Utilities"
        icon: "fas fa-toolbox"
        items:
          - name: "Ferrishare"
            subtitle: "Public File Sharing"
            icon: "fas fa-square-arrow-up-right"
            url: "https://files.${tld}/"
            target: "_blank"
          - name: "Hemmelig"
            subtitle: "Secrets Sharing"
            icon: "fas fa-square-arrow-up-right"
            url: "https://secrets.${tld}/"
            target: "_blank"
          - name: "QR"
            subtitle: "Generate QR Codes"
            icon: "fas fa-qrcode"
            url: "https://qr.${tld}/"
            target: "_blank"
          - name: "Flyers"
            icon: "fas fa-paper-plane"
            url: "https://flyers.${tld}/"
            target: "_blank"
          - name: "STFU"
            icon: "fas fa-volume-xmark"
            url: "https://stfu.${tld}/"
            target: "_blank"
      - name: "Infrastructure"
        icon: "fas fa-heartbeat"
        items:
          - name: "Auth"
            subtitle: "Auth Portal"
            icon: "fas fa-lock"
            url: "https://auth.${tld}/whoami"
            target: "_blank"
          - name: "Grafana"
            subtitle: "Metrics & Logs"
            icon: "fas fa-chart-simple"
            url: "https://monitor.${tld}/"
            target: "_blank"
          - name: "Echo"
            subtitle: "HTTP Connection Info"
            icon: "fas fa-network-wired"
            url: "https://echo.${tld}/"
            target: "_blank"
  '';
in {
  options.services.fluffy.homer = {
    enable = lib.mkEnableOption "Homer home dashboard" // {default = true;};

    serviceName = lib.mkOption {
      type = lib.types.str;
      description = "Systemd service name for the container";
    };

    port = lib.mkOption {
      type = lib.types.port;
      description = "Internal container port";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts."${tld}" = {
      extraConfig = ''
        encode
        authorize with fluff-internal-auth
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
      # NixOS defaults to /var/log/caddy/access-*.log.
      logFormat = "output stderr";
    };

    home-manager.users."${username}" = _: {
      # https://seiarotg.github.io/quadlet-nix/nixos-options.html
      virtualisation.quadlet.containers = {
        "${cfg.serviceName}" = {
          autoStart = true;
          serviceConfig = containerLib.ServiceConfig;
          # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
          containerConfig = {
            image = "docker.io/b4bz/homer:latest";
            autoUpdate = "registry";
            name = cfg.serviceName;

            userns = "";
            podmanArgs = ["--umask=0027"];
            publishPorts = ["127.0.0.1:${toString cfg.port}:8080"];
            mounts = ["type=bind,src=${configFile},dst=/www/assets/config.yml"];
          };
        };
      };
    };
  };
}
