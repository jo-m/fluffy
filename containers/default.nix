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
    ./stfu.nix
    ./traggo.nix
  ];

  config = {
    services.fluffy = {
      echo = {
        serviceName = "echo";
        domain = "echo";
        port = 30010;
      };
      ferrishare = {
        serviceName = "ferrishare";
        domain = "files";
        port = 30020;
      };
      homer = {
        serviceName = "homer";
        port = 30030;
      };
      kitchenowl = {
        serviceName = "kitchenowl";
        domain = "kitchen";
        port = 30040;
      };
      qr = {
        serviceName = "qr";
        domain = "qr";
        port = 30060;
      };
      readeck = {
        serviceName = "readeck";
        domain = "readeck";
        port = 30070;
      };
      hemmelig = {
        serviceName = "hemmelig";
        domain = "secrets";
        port = 30080;
      };
      traggo = {
        serviceName = "traggo";
        domain = "track";
        port = 30090;
      };
      flyermap = {
        serviceName = "flyermap";
        domain = "flyers";
        port = 30100;
      };
      stfu = {
        domain = "stfu";
      };
    };
  };
}
