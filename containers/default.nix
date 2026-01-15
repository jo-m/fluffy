{
  config,
  lib,
  ...
}: {
  imports = [
    ./echo.nix
    ./ferrishare.nix
    ./flyermap.nix
    ./hemmelig.nix
    ./homer.nix
    ./kitchenowl.nix
    ./qr.nix
    ./readeck.nix
    ./traggo.nix
  ];

  config = {
    services.fluffy = {
      echo = {
        serviceName = lib.mkDefault "echo";
        domain = lib.mkDefault "echo";
        port = lib.mkDefault 30010;
      };
      ferrishare = {
        serviceName = lib.mkDefault "ferrishare";
        domain = lib.mkDefault "files";
        port = lib.mkDefault 30020;
      };
      homer = {
        serviceName = lib.mkDefault "homer";
        port = lib.mkDefault 30030;
      };
      kitchenowl = {
        serviceName = lib.mkDefault "kitchenowl";
        domain = lib.mkDefault "kitchen";
        port = lib.mkDefault 30040;
      };
      qr = {
        serviceName = lib.mkDefault "qr";
        domain = lib.mkDefault "qr";
        port = lib.mkDefault 30060;
      };
      readeck = {
        serviceName = lib.mkDefault "readeck";
        domain = lib.mkDefault "readeck";
        port = lib.mkDefault 30070;
      };
      hemmelig = {
        serviceName = lib.mkDefault "hemmelig";
        domain = lib.mkDefault "secrets";
        port = lib.mkDefault 30080;
      };
      traggo = {
        serviceName = lib.mkDefault "traggo";
        domain = lib.mkDefault "track";
        port = lib.mkDefault 30090;
      };
      flyermap = {
        serviceName = lib.mkDefault "flyermap";
        domain = lib.mkDefault "flyers";
        port = lib.mkDefault 30100;
      };
    };
  };
}
