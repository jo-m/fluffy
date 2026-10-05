{...}: {
  imports = [
    ./qr.nix
    ./readeck.nix
    ./traggo.nix
    ./cartomancer.nix
  ];

  config = {
    services.fluffy = {
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
      traggo = {
        serviceName = "traggo";
        domain = "track";
        port = 30090;
      };
      cartomancer = {
        serviceName = "cartomancer";
        domain = "cartomancer";
        port = 30120;
      };
    };
  };
}
