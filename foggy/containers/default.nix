{...}: {
  imports = [
    ./teddycloud.nix
  ];

  config = {
    services.foggy = {
      teddycloud = {
        # domain = "teddycloud";
        port = 30010;
      };
    };
  };
}
