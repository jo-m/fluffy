{
  echo = import ./echo.nix {
    service-name = "echo";
    internal-port = 30001;
  };
}
