{
  lib,
  modules,
  ...
}: {
  microvm = {
    hypervisor = "qemu";
    mem = 2047; # Avoid exactly 2048 which causes QEMU to hang
    vcpu = 2;

    # Share host's nix store with the VM for efficiency.
    # Using 9p as it works without a separate virtiofsd daemon.
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "9p";
      }
    ];

    # Writable overlay for the nix store.
    writableStoreOverlay = "/nix/.rw-store";

    # Persistent data volume.
    volumes = [
      {
        image = "data.img";
        mountPoint = "/data";
        size = 4096;
      }
    ];

    # Network interface for the VM (user mode networking).
    interfaces = [
      {
        type = "user";
        id = "usernet";
        mac = "02:00:00:00:00:01";
      }
    ];

    # Forward ports from host to VM.
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
      {
        from = "host";
        host.port = 8080;
        guest.port = 80;
      }
      {
        from = "host";
        host.port = 8443;
        guest.port = 443;
      }
    ];
  };

  imports = lib.flatten [
    ./configuration-stage0.nix

    (with modules; [
      options
      ssh
      harden
      rootless-podman
    ])
  ];
}
