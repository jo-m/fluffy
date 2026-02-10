{lib, ...}: {
  options.fluffy = {
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

    tld = lib.mkOption {
      type = lib.types.str;
      description = "Top-level domain for services";
      default = builtins.getEnv "REMOTE_TLD";
    };

    data-base-dir = lib.mkOption {
      type = lib.types.path;
      description = "Base directory for persistent data";
      default = "/data";
    };
  };
}
