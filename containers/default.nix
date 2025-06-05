{
  echo = import ./echo.nix {
    service-name = "echo";
    internal-port = 30001;
  };
  openobserve = import ./openobserve.nix {
    service-name = "openobserve";
    internal-port = 30004;
  };
  qr = import ./qr.nix {
    service-name = "qr";
    internal-port = 30003;
  };
  readeck = import ./readeck.nix {
    service-name = "readeck";
    internal-port = 30002;
  };
  webdav = import ./webdav.nix {
    service-name = "webdav";
  };
}
