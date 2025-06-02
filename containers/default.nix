{
  echo = import ./echo.nix {
    service-name = "echo";
    internal-port = 30001;
  };
  readeck = import ./readeck.nix {
    service-name = "readeck";
    internal-port = 30002;
  };
  qr = import ./qr.nix {
    service-name = "qr";
    internal-port = 30003;
  };
}
