{...}: {
  imports = [
    ./teddycloud.nix
  ];

  config = {
    services.foggy = {
      teddycloud = {
        port = 30010;
      };
    };
  };
}
