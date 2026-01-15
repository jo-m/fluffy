{
  config,
  lib,
  ...
}:
with lib; {
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
        serviceName = mkDefault "echo";
        domain = mkDefault "echo";
        port = mkDefault 30010;
      };
      ferrishare = {
        serviceName = mkDefault "ferrishare";
        domain = mkDefault "files";
        port = mkDefault 30020;
      };
      homer = {
        serviceName = mkDefault "homer";
        domain = mkDefault "files";
        port = mkDefault 30030;
      };
      kitchenowl = {
        serviceName = mkDefault "kitchenowl";
        domain = mkDefault "kitchen";
        port = mkDefault 30040;
      };
      qr = {
        serviceName = mkDefault "qr";
        domain = mkDefault "qr";
        port = mkDefault 30060;
      };
      readeck = {
        serviceName = mkDefault "readeck";
        domain = mkDefault "readeck";
        port = mkDefault 30070;
      };
      hemmelig = {
        serviceName = mkDefault "hemmelig";
        domain = mkDefault "secrets";
        port = mkDefault 30080;
      };
      traggo = {
        serviceName = mkDefault "traggo";
        domain = mkDefault "track";
        port = mkDefault 30090;
      };
      flyermap = {
        serviceName = mkDefault "flyermap";
        domain = mkDefault "flyers";
        port = mkDefault 30100;
      };
    };
  };
}
