{
  echo = import ./echo.nix {
    service-name = "echo";
    domain = "echo";
    internal-port = 30001;
  };
  ferrishare = import ./ferrishare.nix {
    service-name = "ferrishare";
    domain = "share";
    internal-port = 30002;
  };
  openobserve = import ./openobserve.nix {
    service-name = "openobserve";
    domain = "logs";
    internal-port = 30003;
  };
  qr = import ./qr.nix {
    service-name = "qr";
    domain = "qr";
    internal-port = 30004;
  };
  readeck = import ./readeck.nix {
    service-name = "readeck";
    domain = "readeck";
    internal-port = 30005;
  };
  webdav = import ./webdav.nix {
    service-name = "webdav";
    domain = "webdav";
  };
}
