{
  echo = import ./echo.nix {
    service-name = "echo";
    domain = "echo";
    internal-port = 30010;
  };
  ferrishare = import ./ferrishare.nix {
    service-name = "ferrishare";
    domain = "files";
    internal-port = 30020;
  };
  homer = import ./homer.nix {
    service-name = "homer";
    domain = "files";
    internal-port = 30030;
  };
  kitchenowl = import ./kitchenowl.nix {
    service-name = "kitchenowl";
    domain = "kitchen";
    internal-port = 30040;
  };
  openobserve = import ./openobserve.nix {
    service-name = "openobserve";
    domain = "monitor";
    # When you change this, also update `opentelemetry-collector.nix`.
    internal-port = 30050;
    internal-port-grpc = 30051;
  };
  qr = import ./qr.nix {
    service-name = "qr";
    domain = "qr";
    internal-port = 30060;
  };
  readeck = import ./readeck.nix {
    service-name = "readeck";
    domain = "readeck";
    internal-port = 30070;
  };
  hemmelig = import ./hemmelig.nix {
    service-name = "hemmelig";
    domain = "secrets";
    internal-port = 30080;
  };
  traggo = import ./traggo.nix {
    service-name = "traggo";
    domain = "track";
    internal-port = 30090;
  };
}
