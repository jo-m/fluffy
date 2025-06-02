{
  echo = import ./echo.nix {
    service-name = "echo";
    internal-port = 30001;
  };
  readeck = import ./readeck.nix {
    service-name = "readeck";
    internal-port = 30002;
  };
}
