{lib, ...}: {
  options.fluffy = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Primary unprivileged user which will run containers.";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      description = "UID for the primary user";
    };

    tld = lib.mkOption {
      type = lib.types.str;
      description = "Top-level domain for services";
    };

    data-base-dir = lib.mkOption {
      type = lib.types.path;
      description = "Base directory for persistent data";
    };
  };
}
