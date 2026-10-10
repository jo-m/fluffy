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
        subdomain = "qr";
        port = 30060;
      };
      readeck = {
        serviceName = "readeck";
        subdomain = "readeck";
        port = 30070;
      };
      traggo = {
        serviceName = "traggo";
        subdomain = "track";
        port = 30090;
      };
      cartomancer = {
        serviceName = "cartomancer";
        subdomain = "cartomancer";
        port = 30120;
      };
    };
  };
}
