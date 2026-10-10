{lib, ...}: {
  options.custom = {
    username = lib.mkOption {
      type = lib.types.str;
      description = "Primary unprivileged user which will run containers.";
      default = "runner";
    };

    uid = lib.mkOption {
      type = lib.types.ints.positive;
      description = "UID for the primary user";
      default = 1000;
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Top-level domain for services";
      default = builtins.getEnv "REMOTE_DOMAIN";
    };

    data-base-dir = lib.mkOption {
      type = lib.types.path;
      description = "Base directory for persistent data";
      default = "/data";
    };
  };
}
